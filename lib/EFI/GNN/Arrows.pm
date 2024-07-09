
package EFI::GNN::Arrows;

use strict;
use warnings;
use DBI;
use Data::Dumper;

our $AttributesTable = "attributes";
our $NeighborsTable = "neighbors";
our $Version = 3;


sub new {
    my ($class, %args) = @_;
    
    my $self = {};
    if (exists $args{color_util}) {
        $self->{color_util} = $args{color_util};
    } else {
        $self->{color_util} = new DummyColorUtil;
    }

    $self->{uniref_version} = $args{uniref_version} // 0;
    if ($args{ssn_type} and $args{ssn_type} =~ m/^uniref(\d+)$/i) {
        $self->{uniref_version} = $1;
    }

    return bless($self, $class);
}




sub setSsnType {
    my $self = shift;
    my $type = shift;
    
}


sub getDbh {
    my $self = shift;
    my $file = shift;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$file","","");
    return $dbh;
}


sub writeArrowData {
    my $self = shift;
    my $data = shift;
    my $clusterCenters = shift;
    my $file = shift;
    my $metadata = shift;
    my $orderedIds = shift;
    my $ur50 = shift || {};
    my $ur90 = shift || {};

    unlink $file if -f $file;

    #my $dbh = DBI->connect("dbi:SQLite:dbname=$file","","");
    my $dbh = $self->getDbh($file);
    $dbh->{AutoCommit} = 0;

#    my $trans = sub {
#        $dbh->begin_work;
#        &{$_[0]};
#        $dbh->commit;
#    };

#    &$trans(sub {
        $self->createSchema($dbh);
#    });

#    &$trans(sub {
        $self->saveMetadata($dbh, $metadata, $clusterCenters);
#    });

    my $sortedIds = $self->sortIds($data, $orderedIds);
    my @sortedIds = @$sortedIds;
    print "NUM AIDS: " . (scalar @sortedIds) . "\n";

    my ($extents, $indexMap, $clusterMap);
    my $numInsert = 0;
    my $t1 = time;
    my $insertHandler = sub {
        my ($dbh, $sql) = @_;
        if ($numInsert++ > 100000) {
            $dbh->commit;
            $numInsert = 0;
#            $t1 = printTime($t1, "insert 50");
        }
        #$dbh->begin_work if not $numInsert;
        $dbh->do($sql);
    };
    ($extents, $indexMap, $clusterMap) = $self->saveData($dbh, $data, $sortedIds, $insertHandler);
    $dbh->commit;
#    print "Yup\n";
#    die;

#    &$trans(sub {
        $self->saveExtents($dbh, $extents);
#    });

    # Save UniRef map (one-to-many, UniRef50 ID -> UniRef90 ID, or UniRef90 ID -> UniProt ID)
    if ($self->{uniref_version}) {
#        &$trans(sub {
            $self->saveUniRef($dbh, $ur50, $ur90, $indexMap, $clusterMap, $insertHandler);
#        });
    }

    $dbh->commit;

    $dbh->disconnect();
    print "Done with loading database\n";
}

sub printTime {
    my ($t1, $name) = @_;
    $name = $name // "t";
    printf("$name=%.6f s\n", (time - $t1));
    return time;
}
sub createSchema {
    my $self = shift;
    my $dbh = shift;

    my @sqlStatements = getCreateAttributeTableSql($self->{uniref_version});
    push @sqlStatements, getCreateNeighborTableSql();
    push @sqlStatements, getCreateFamilyTableSql();
    push @sqlStatements, getCreateDegreeTableSql();
    push @sqlStatements, getCreateMetadataTableSql();
    push @sqlStatements, getClusterIndexTableSql();
    push @sqlStatements, getUniRefMappingSql($self->{uniref_version}) if $self->{uniref_version} > 0;
    foreach my $sql (@sqlStatements) {
        $dbh->do($sql);
    }
}

sub saveMetadata {
    my $self = shift;
    my $dbh = shift;
    my $metadata = shift;
    my $clusterCenters = shift;

    my (@cols, @vals);

    if (exists $metadata->{cooccurrence}) {
        push @cols, "cooccurrence";
        push @vals, $metadata->{cooccurrence};
    }
    if (exists $metadata->{neighborhood_size}) {
        push @cols, "neighborhood_size";
        push @vals, $metadata->{neighborhood_size};
    }
    if (exists $metadata->{title}) {
        push @cols, "name";
        push @vals, $metadata->{title};
    }
    if (exists $metadata->{type}) {
        push @cols, "type";
        push @vals, $metadata->{type};
    }
    if (exists $metadata->{sequence}) {
        push @cols, "sequence";
        push @vals, $metadata->{sequence};
    }

    my $sql = "INSERT INTO metadata (" . join(", ", @cols) . ") VALUES(" .
        join(", ", map { $dbh->quote($_) } @vals) . ")";
    $dbh->do($sql);

    foreach my $clusterNum (keys %$clusterCenters) {
        my $sql = "INSERT INTO cluster_degree (cluster_num, accession, degree) VALUES (" .
                    $dbh->quote($clusterNum) . "," .
                    $dbh->quote($clusterCenters->{$clusterNum}->{id}) . "," .
                    $dbh->quote($clusterCenters->{$clusterNum}->{degree}) . ")";
        $dbh->do($sql);
    }
}

sub saveData {
    my $self = shift;
    my $dbh = shift;
    my $data = shift;
    my $sortedIds = shift;
    my $insertTransactionHandler = shift;

    my %extents;
    my %families;
    my $clusterIndex = 0;
    my $lastCluster = -1;
    my $start = -1;
    my %indexMap;
    my %clusterMap;

    foreach my $id (@$sortedIds) {
        # If the accession key doesn't exist, then it doesn't have any genomic data associated with it,
        # probably because it's a eukaroyte.
        print "SKIPPING UniProt $id because it doesn't have any data\n" and next if not $data->{$id}->{attributes}->{accession};

        # Here we determine the range of cluster indexes in each cluster.
        my $clusterNum = $data->{$id}->{attributes}->{cluster_num};
        if ($clusterNum != $lastCluster) {
            if ($start != -1) {
                $extents{$lastCluster} = [$start, $clusterIndex-1];
            }
            $lastCluster = $clusterNum;
            $start = $clusterIndex;
        }
        $indexMap{$id} = $clusterIndex;
        $clusterMap{$id} = $clusterNum;

        my @args = ($EFI::GNN::Arrows::AttributesTable, $data->{$id}->{attributes}, $dbh, $clusterIndex);
        push @args, $self->{uniref_version} if $self->{uniref_version};
        my $sql = $self->getInsertStatement(@args);
        &$insertTransactionHandler($dbh, $sql);
        my $geneKey = $dbh->last_insert_id(undef, undef, undef, undef);
        $families{$data->{$id}->{attributes}->{family}} = 1 if $data->{$id}->{attributes}->{family};
        $families{$data->{$id}->{attributes}->{ipro_family}} = 1 if $data->{$id}->{attributes}->{ipro_family};

        foreach my $nb (sort { $a->{num} cmp $b->{num} } @{ $data->{$id}->{neighbors} }) {
            $nb->{gene_key} = $geneKey;
            $sql = $self->getInsertStatement($EFI::GNN::Arrows::NeighborsTable, $nb, $dbh);
            &$insertTransactionHandler($dbh, $sql);
            $families{$nb->{family}} = 1;
            $families{$nb->{ipro_family}} = 1;
        }
        $clusterIndex++;
    }
    $extents{$lastCluster} = [$start, $clusterIndex-1];
    
    foreach my $id (sort keys %families) {
        my $sql = "INSERT INTO families (family) VALUES (" . $dbh->quote($id) . ")";
        &$insertTransactionHandler($dbh, $sql);
    }

    return \%extents, \%indexMap, \%clusterMap;
}

sub sortIds {
    my $self = shift;
    my $data = shift;
    my $orderedIds = shift;

    # Sort first by cluster number then by accession.
    my $sortFn = sub {
        return 0 if not $data->{$a}->{attributes} and not $data->{$b}->{attributes};
        return 1 if not $data->{$a}->{attributes};
        return -1 if not $data->{$b}->{attributes};

        die "A $a" if not defined $data->{$a}->{attributes}->{cluster_num};
        die "B $b" if not defined $data->{$b}->{attributes}->{cluster_num};
        my $comp = $data->{$a}->{attributes}->{cluster_num} <=> $data->{$b}->{attributes}->{cluster_num};
        return $comp if $comp;
        return $data->{$a}->{attributes}->{evalue} <=> $data->{$b}->{attributes}->{evalue}
            if exists $data->{$a}->{attributes}->{evalue} and exists $data->{$b}->{attributes}->{evalue};
        return 1 if not $data->{$a}->{attributes}->{accession};
        return -1 if not $data->{$b}->{attributes}->{accession};
        $comp = $data->{$a}->{attributes}->{accession} cmp $data->{$b}->{attributes}->{accession};
        return $comp;
    };
    my @sortedIds = keys %$data;
    if (defined $orderedIds and ref $orderedIds eq "ARRAY" and scalar @$orderedIds == scalar @sortedIds) {
        @sortedIds = @$orderedIds;
    } elsif (scalar @sortedIds and exists $data->{$sortedIds[0]}->{attributes}->{cluster_num}) {
        @sortedIds = sort $sortFn @sortedIds;
    } else {
        @sortedIds = sort @sortedIds;
    }

    # Sort by UniRef cluster size
    #my $uniRefSortFn = sub {
    #    my $comp = $data->{$b}->{attributes}->{uniref90_size} <=> $data->{$a}->{attributes}->{uniref90_size};
    #    return $comp if $comp;
    #    if ($self->{uniref_version} == 50) {
    #        $comp = $data->{$b}->{attributes}->{uniref50_size} <=> $data->{$a}->{attributes}->{uniref50_size};
    #        return $comp if $comp;
    #    }
    #    $comp = ($data->{$b}->{attributes}->{accession} // "") cmp ($data->{$a}->{attributes}->{accession} // "");
    #    return $comp;
    #};
    #if ($self->{uniref_version}) {
    #    @sortedIds = sort $uniRefSortFn @sortedIds;
    #}

    return \@sortedIds;
}

sub saveExtents {
    my $self = shift;
    my $dbh = shift;
    my $extents = shift;

    foreach my $num (sort {$a<=>$b} keys %$extents) {
        next if not exists $extents->{$num};
        my ($min, $max) = @{$extents->{$num}};
        my $sql = "INSERT INTO cluster_index (cluster_num, start_index, end_index) VALUES ($num, $min, $max)";
        $dbh->do($sql);
    }
}

sub saveUniRef {
    my $self = shift;
    my $dbh = shift;
    my $ur50 = shift;
    my $ur90 = shift;
    my $indexMap = shift;   # Map of UniProt ID to UniProt table index
    my $clusterMap = shift; # Map of UniProt ID to UniProt SSN cluster number
    my $insertTransactionHandler = shift;

    my $makeSortFn = sub {
        my $sortHash = shift;
        return sub {
            my $comp = scalar @{$sortHash->{$b}} <=> scalar @{$sortHash->{$a}};
            return $comp if $comp;
            return $a cmp $b;
        };
    };

    # cluster_index = index of UniRef ID within a sorted SSN cluster
    # cluster_num = SSN cluster number

    my $ur50SortFn = &$makeSortFn($ur50);
    my $ur90SortFn = &$makeSortFn($ur90);
    my $insertUniRefFn = sub {
        my $sortFn = shift;
        my $uniref = shift;
        my $ver = shift;
        my $ur90SortFn = shift || 0;

        my @rawUrIds = sort $sortFn keys %$uniref;
        my %clusters;
        map { push @{$clusters{$clusterMap->{$_}}}, $_ if $clusterMap->{$_}; } @rawUrIds; 

        my $uniProtIndex = 0;
        my %clusterNumIndexMap;
        my $uniRefIndex = 0;

        print "START\n";

        foreach my $clusterNum (sort { $a <=> $b } keys %clusters) {
            my @urIds = sort $sortFn @{$clusters{$clusterNum}};
            my $startUniRefIndex = $uniRefIndex;
            foreach my $unirefId (@urIds) {
                my $unirefClusterIndex = $indexMap->{$unirefId};
                print "SKIPPING UniRef${ver} cluster ID because it's not found in UniProt cluster list, due to not having any ENA data\n"
                    and next if not $unirefClusterIndex;
                my @uniprotIds = @{$uniref->{$unirefId}};
                @uniprotIds = sort $ur90SortFn @uniprotIds if $ur90SortFn;
                my $delta = 0;
                foreach my $uniprotId (@uniprotIds) {
                    my $clusterIndex = $indexMap->{$uniprotId};
                    my $clNum = $clusterMap->{$uniprotId} // "";
                    print "SKIPPING UniRef${ver} cluster member $uniprotId because not found in UniProt cluster index\n"
                        and next if not defined $clusterIndex;
                    $clusterNumIndexMap{$clNum}->{start} = $startUniRefIndex if not exists $clusterNumIndexMap{$clNum}->{start};
                    $clusterNumIndexMap{$clNum}->{end} = $uniRefIndex;
                    my $c = $uniProtIndex + $delta;
                    my $sql = "INSERT INTO uniref${ver}_index (member_index, cluster_index) VALUES ($c, $clusterIndex)";
#                    print STDERR "$sql\n";
                    &$insertTransactionHandler($dbh, $sql);
#                    $dbh->do($sql);
                    $delta++;
                }
                my $end = $uniProtIndex + $delta - 1;
                my $idVal = $dbh->quote($unirefId);
                my $sql = "INSERT INTO uniref${ver}_range (uniref_index, uniref_id, start_index, end_index, cluster_index) VALUES ($uniRefIndex, $idVal, $uniProtIndex, $end, $unirefClusterIndex)";
#                print STDERR "$sql\n";
                &$insertTransactionHandler($dbh, $sql);
#                $dbh->do($sql);
                $uniProtIndex += $delta;
                $uniRefIndex++;
            }
            #foreach my $clusterNum (sort {$a<=>$b} keys %clusterNumIndexMap) {
            if (not $clusterNumIndexMap{$clusterNum}) {
                print "Unable to find UniRef${ver} cluster number $clusterNum\n";
                next;
            }
            my $s = $clusterNumIndexMap{$clusterNum}->{start};
            my $e = $clusterNumIndexMap{$clusterNum}->{end};
            my $sql = "INSERT INTO uniref${ver}_cluster_index"
                . " (cluster_num, start_index, end_index)"
                . " VALUES ($clusterNum, $s, $e)";
            &$insertTransactionHandler($dbh, $sql);
#            print STDERR "$sql\n";
#            $dbh->do($sql);
           #}
       }
    };
   
    &$insertUniRefFn($ur50SortFn, $ur50, "50", $ur90SortFn) if $self->{uniref_version} == 50;
    print "Done with UniRef50\n";
    &$insertUniRefFn($ur90SortFn, $ur90, "90") if $self->{uniref_version} >= 50;
    print "Done with UniRef90\n";
}


sub writeClusterMapping {
    my $self = shift;
    my $dbFile = shift;
    my $mapping = shift;
    
    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbFile","","");
    $dbh->{AutoCommit} = 0;

    my @sql;
    #push @sql, "CREATE TABLE cluster_num_map (cluster_num INTEGER, ascore INTEGER, cluster_id TEXT)";
    #push @sql, "CREATE INDEX cluster_num_map_index ON cluster_num_map (cluster_num, ascore, cluster_id)";
    push @sql, "CREATE TABLE cluster_num_map (cluster_num INTEGER, cluster_id TEXT)";
    push @sql, "CREATE INDEX cluster_num_map_index ON cluster_num_map (cluster_num, cluster_id)";

    foreach my $sql (@sql) {
        $dbh->do($sql);
    }
    $dbh->commit;

    foreach my $id (sort { $a cmp $b } keys %$mapping) {
        my $info = $mapping->{$id};
        my @cols = ("cluster_id", "cluster_num");
        #push @cols, "ascore" if ref $info and $info->{ascore};
        #my @vals = ($id, $info->{cluster_num});
        #push @vals, $info->{ascore} if ref($info) and $info->{ascore};
        my @vals = ($id, $info);
        my $cols = join(", ", @cols);
        my $vals = join(", ", map { "'$_'" } @vals);
        my $sql = "INSERT INTO cluster_num_map ($cols) VALUES ($vals)";
        $dbh->do($sql);
    }
    $dbh->commit;

    $dbh->disconnect;
}


sub writeUnmatchedIds {
    my $self = shift;
    my $file = shift;
    my $ids = shift;
    
    my $dbh = DBI->connect("dbi:SQLite:dbname=$file","","");
    $dbh->{AutoCommit} = 0;

    my $createSql = getCreateUnmatchedIdsTableSql();
    $dbh->do($createSql);

    foreach my $idList (@$ids) {
        my $sql = "INSERT INTO unmatched (id_list) VALUES (" . $dbh->quote($idList) . ")";
        $dbh->do($sql);
    }

    $dbh->commit;
    $dbh->disconnect;
}


sub writeMatchedIds {
    my $self = shift;
    my $file = shift;
    my $ids = shift;
    
    my $dbh = DBI->connect("dbi:SQLite:dbname=$file","","");
    $dbh->{AutoCommit} = 0;

    my $createSql = getCreateMatchedIdsTableSql();
    $dbh->do($createSql);

    foreach my $uniprotId (keys %$ids) {
        my $idList = join(",", @{$ids->{$uniprotId}});
        my $sql = "INSERT INTO matched (uniprot_id, id_list) VALUES (" . $dbh->quote($uniprotId) . ", " . $dbh->quote($idList) . ")";
        $dbh->do($sql);
    }

    $dbh->commit;
    $dbh->disconnect;
}


sub getCreateAttributeTableSql {
    my $uniRefVersion = shift || 0;
    my @statements;
    my $cols = getAttributeColsSql();
    $cols .= <<SQL;
                        ,
                        sort_order INTEGER,
                        strain VARCHAR(2000),
                        cluster_num INTEGER,
                        organism VARCHAR(2000),
                        is_bound INTEGER,
                        evalue REAL,
                        cluster_index INTEGER
SQL
    $cols .= ",uniref90_size INTEGER" if $uniRefVersion >= 50;
    $cols .= ",uniref50_size INTEGER" if $uniRefVersion == 50;
    # is_bound: 0 - not encountering any contig boundary; 1 - left; 2 - right; 3 - bo,

    my $sql = "CREATE TABLE $EFI::GNN::Arrows::AttributesTable ($cols)";
    push @statements, $sql;
    $sql = "CREATE INDEX ${EFI::GNN::Arrows::AttributesTable}_ac_index ON $EFI::GNN::Arrows::AttributesTable (accession)";
    push @statements, $sql;
    $sql = "CREATE INDEX ${EFI::GNN::Arrows::AttributesTable}_cl_num_index ON $EFI::GNN::Arrows::AttributesTable (cluster_num)";
    push @statements, $sql;
    $sql = "CREATE INDEX ${EFI::GNN::Arrows::AttributesTable}_cl_index_index ON $EFI::GNN::Arrows::AttributesTable (cluster_index)";
    push @statements, $sql;
    return @statements;
}


sub getClusterIndexTableSql {
    my @statements;
    push @statements, "CREATE TABLE cluster_index (cluster_num INTEGER, start_index INTEGER, end_index INTEGER)";
    push @statements, "CREATE INDEX cluster_num_table_index ON cluster_index (cluster_num)";
    return @statements;
}


sub getUniRefMappingSql {
    my $ver = shift;
    my @statements;
    # Maps a cluster to uniref## index
    # The way this works is as follows:
    #   1. If user loads UniRef50 GND:
    #       a. Query uniref_cluster_index table for the requested cluster
    #       b. Get uniref##_start/end_index
    #       c. Query uniref##_index table using indexes from (b)
    #       d. Get list of cluster_index, corresponding to the UniRef50 IDs
    #       e. Query attribute table using cluster_index list (just like UniProt)
    #   2. If user loads UniRef50 GND:
    #       a. (a)->(c) from (1)
    #       b. 
    #       c. 
    #       d. Get list of cluster_index, corresponding to the UniRef90 IDs
    #       e. (e) from (1)
    #   3. If user loads UniProt use getClusterIndexTableSql
    #   4. If user loads UniRef50 GND but requests specific UniRef50 ID cluster:
    #       a. Query uniref50_range for the specific uniref50_id
    #       b. Get list of start_index/end_index which correspond to the UniRef90 IDs in the UniRef50 cluster
    #       c. Query uniref50_index using the index list from (b) as uniref_index
    #       d. Get list of cluster_index, corresponding to the UniRef90 IDs
    #       e. Query attribute table using the index list
    #   5. If user loads UniRef90 GND but requests specific UniRef90 ID cluster:
    #       a. Query uniref90_range for the specific uniref90_id
    #       b. Get list of start_index/end_index which correspond to the UniProt IDs in the UniRef90 cluster
    #       c. Query uniref90_index using the index list from (b) as uniref_index
    #       d. Get list of cluster_index, corresponding to the UniProt IDs
    #       e. Query attribute table using the index list
    if ($ver == 50) {
        push @statements, "CREATE TABLE uniref50_cluster_index (cluster_num INTEGER, start_index INTEGER, end_index INTEGER)";
        push @statements, "CREATE INDEX uniref50_cluster_num_table_index ON uniref50_cluster_index (cluster_num)";
        push @statements, "CREATE TABLE uniref50_range (uniref_index INTEGER, uniref_id VARCHAR(10), start_index INTEGER, end_index INTEGER, cluster_index INTEGER);";
        push @statements, "CREATE INDEX uniref50_range_table_index ON uniref50_range (uniref_index, uniref_id)";
        # Maps a uniref## range index to the UniProt cluster_index in the attributes table
        # The member_index column corresponds to the start_index/end_index columns of the uniref##_range table
        push @statements, "CREATE TABLE uniref50_index (member_index INTEGER, cluster_index INTEGER);";
        push @statements, "CREATE INDEX uniref50_index_table_index ON uniref50_index (member_index)";
    }
    if ($ver >= 50) {
        push @statements, "CREATE TABLE uniref90_cluster_index (cluster_num INTEGER, start_index INTEGER, end_index INTEGER)";
        push @statements, "CREATE INDEX uniref90_cluster_num_table_index ON uniref90_cluster_index (cluster_num)";
        push @statements, "CREATE TABLE uniref90_range (uniref_index INTEGER, uniref_id VARCHAR(10), start_index INTEGER, end_index INTEGER, cluster_index INTEGER);";
        push @statements, "CREATE INDEX uniref90_range_table_index ON uniref90_range (uniref_index, uniref_id)";
        push @statements, "CREATE TABLE uniref90_index (member_index INTEGER, cluster_index INTEGER);";
        push @statements, "CREATE INDEX uniref90_index_table_index ON uniref90_index (member_index)";
    }
    return @statements;
}


sub getCreateNeighborTableSql {
    my $cols = getAttributeColsSql();
    $cols .= "\n                        , gene_key INTEGER";

    my @statements;
    push @statements, "CREATE TABLE $EFI::GNN::Arrows::NeighborsTable ($cols)";
    push @statements, "CREATE INDEX ${EFI::GNN::Arrows::NeighborsTable}_ac_id_index ON $EFI::GNN::Arrows::NeighborsTable (gene_key)";
    return @statements;
}

sub getAttributeColsSql {
    my $sql = <<SQL;
                        sort_key INTEGER PRIMARY KEY AUTOINCREMENT,
                        accession VARCHAR(10),
                        id VARCHAR(20),
                        num INTEGER,
                        family VARCHAR(1800),
                        ipro_family VARCHAR(1800),
                        start INTEGER,
                        stop INTEGER,
                        rel_start INTEGER,
                        rel_stop INTEGER,
                        direction VARCHAR(10),
                        type VARCHAR(10),
                        seq_len INTEGER,
                        taxon_id VARCHAR(20),
                        anno_status VARCHAR(255),
                        desc VARCHAR(255),
                        family_desc VARCHAR(255),
                        ipro_family_desc VARCHAR(255),
                        color VARCHAR(255)
SQL
    return $sql;
}

sub getCreateFamilyTableSql {
    my $sql = <<SQL;
CREATE TABLE families (family VARCHAR(1800));
SQL
    return $sql;
}

sub getCreateUnmatchedIdsTableSql {
    my $sql = <<SQL;
CREATE TABLE unmatched (id_list TEXT);
SQL
    return $sql;
}

sub getCreateMatchedIdsTableSql {
    my $sql = <<SQL;
CREATE TABLE matched (uniprot_id VARCHAR(10), id_list TEXT);
SQL
    return $sql;
}

sub getCreateDegreeTableSql {
    my @statements;
    my $sql = "CREATE TABLE cluster_degree (cluster_num INTEGER PRIMARY KEY, accession VARCHAR(10), degree INTEGER);";
    push @statements, $sql;
    $sql = "CREATE INDEX degree_cluster_num_index on cluster_degree (cluster_num)";
    push @statements, $sql;
    return @statements;
}


sub getCreateMetadataTableSql {
    my @statements;
    my $sql = "CREATE TABLE metadata (cooccurrence REAL, name VARCHAR(255), neighborhood_size INTEGER, type VARCHAR(10), sequence TEXT);";
    push @statements, $sql;
    return @statements;
}


sub getInsertStatement {
    my $self = shift;
    my $table = shift;
    my $attr = shift;
    my $dbh = shift;
    my $clusterIndex = shift;
    my $uniRefVersion = shift || 0;

    my @addlCols;
    push @addlCols, exists $attr->{strain} ? ",strain" : "";
    push @addlCols, exists $attr->{cluster_num} ? ",cluster_num" : "";
    push @addlCols, exists $attr->{gene_key} ? ",gene_key" : "";
    push @addlCols, exists $attr->{organism} ? ",organism" : "";
    push @addlCols, exists $attr->{is_bound} ? ",is_bound" : "";
    push @addlCols, exists $attr->{sort_order} ? ",sort_order" : "";
    push @addlCols, exists $attr->{evalue} ? ",evalue" : "";
    push @addlCols, defined $clusterIndex ? ",cluster_index" : "";
    push @addlCols, ",uniref90_size" if $uniRefVersion >= 50;
    push @addlCols, ",uniref50_size" if $uniRefVersion == 50;
    #my $addlCols = $strainCol . $clusterNumCol . $geneKeyCol . $organismCol . $isBoundCol . $orderCol . $evalueCol;
    my $addlCols = join("", @addlCols);

    # If the family field is a fusion of multiple pfams, we get the color for each pfam in the fusion
    # as well as a color for the fusion.
    my $color = join(",", $self->{color_util}->getColorForPfam($attr->{family}));

    my $sql = "INSERT INTO $table (accession, id, num, family, ipro_family, start, stop, rel_start, rel_stop, direction, type, seq_len, taxon_id, anno_status, desc, family_desc, ipro_family_desc, color $addlCols) VALUES (";
    $sql .= $dbh->quote($attr->{accession}) . ",";
    $sql .= $dbh->quote($attr->{id}) . ",";
    $sql .= $dbh->quote($attr->{num}) . ",";
    $sql .= $dbh->quote($attr->{family}) . ",";
    $sql .= $dbh->quote($attr->{ipro_family}) . ",";
    $sql .= $dbh->quote($attr->{start}) . ",";
    $sql .= $dbh->quote($attr->{stop}) . ",";
    $sql .= $dbh->quote($attr->{rel_start}) . ",";
    $sql .= $dbh->quote($attr->{rel_stop}) . ",";
    $sql .= $dbh->quote($attr->{direction}) . ",";
    $sql .= $dbh->quote($attr->{type}) . ",";
    $sql .= $dbh->quote($attr->{seq_len}) . ",";
    $sql .= $dbh->quote($attr->{taxon_id}) . ",";
    $sql .= $dbh->quote($attr->{anno_status}) . ",";
    $sql .= $dbh->quote($attr->{desc}) . ",";
    $sql .= $dbh->quote($attr->{family_desc}) . ",";
    $sql .= $dbh->quote($attr->{ipro_family_desc}) . ",";
    $sql .= $dbh->quote($color);
    $sql .= "," . $dbh->quote($attr->{strain}) if exists $attr->{strain};
    $sql .= "," . $dbh->quote($attr->{cluster_num}) if exists $attr->{cluster_num};
    $sql .= "," . $dbh->quote($attr->{gene_key}) if exists $attr->{gene_key};
    $sql .= "," . $dbh->quote($attr->{organism}) if exists $attr->{organism};
    $sql .= "," . $dbh->quote($attr->{is_bound}) if exists $attr->{is_bound};
    $sql .= "," . $dbh->quote($attr->{sort_order}) if exists $attr->{sort_order};
    $sql .= "," . $dbh->quote($attr->{evalue}) if exists $attr->{evalue};
    $sql .= "," . $dbh->quote($clusterIndex) if defined $clusterIndex;
    $sql .= "," . $dbh->quote($attr->{uniref90_size}) if $uniRefVersion >= 50;
    $sql .= "," . $dbh->quote($attr->{uniref50_size}) if $uniRefVersion == 50;
    $sql .= ")";

    return $sql;
}


#sub exportIdInfo {
#    my $self = shift;
#    my $sqliteFile = shift;
#    my $outFile = shift;
#
#    my $dbh = DBI->connect("dbi:SQLite:dbname=$sqliteFile","","");
#    
#    my $sql = "SELECT * FROM $EFI::GNN::Arrows::AttributesTable";
#    my $sth = $dbh->prepare($sql);
#    $sth->execute();
#
#    my %groupData;
#
#    while (my $row = $sth->fetchrow_hashref()) {
#        $groupData->{$row->{accession}} = {
#            gene_id => $row->{id},
#            seq_len => $row->{seq_len},
#            product => "",
#            organism => "", #$row->{strain},
#            taxonomy => "",
#            description => "",
#            contig_edge => 0, #TODO: compute this correctly
#            gene_key => $row->{sort_key},
#            neighbors => [],
#            position => $row->{num},
#        };
#    }
#
#    foreach my $id (sort keys %groupData) {
#        $sql = "SELECT * FROM $EFI::GNN::Arrows::NeighborsTable WHERE gene_key = " . $groupData{$id}->{gene_key} . " ORDER BY num";
#        $sth = $dbh->prepare($sql);
#        $sth->execute();
#
#        while (my $row = $sth->fetchrow_hashref()) {
#            my $num = $row->{num};
#            # Insert the main query/cluster ID into the middle of the neighbors where it belongs.
#            if ($row->{num} < $num) {
#                
#            }
#        }
#    }
#}



sub computeClusterCenters {
    my $self = shift;
    my $gnnUtil = shift;
    my $degrees = shift;

    my @clusterNumbers = $gnnUtil->getClusterNumbers();

    my %centers;
    foreach my $clusterNum (@clusterNumbers) {
        my $nodes = $gnnUtil->getAllIdsInCluster($clusterNum);

        if ($gnnUtil->isSingleton($clusterNum) and scalar @$nodes > 1) {
            $centers{$clusterNum} = {degree => 1, id => $nodes->[0]};
        } else {
            foreach my $acc (@$nodes) {
                next if not exists $degrees->{$acc};
                if (not exists $centers{$clusterNum} or $degrees->{$acc} > $centers{$clusterNum}->{degree}) {
                    $centers{$clusterNum} = {degree => $degrees->{$acc}, id => $acc};
                }
            }
        }
    }

    return \%centers;
}


sub getDbVersion {
    my $dbFile = shift;

    my $version = 2;

    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbFile","","");

    my $sql = "SELECT * FROM sqlite_master WHERE type='table' AND name = 'cluster_index'";
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    if ($sth->fetchrow_hashref()) {
        $version = 3;
    }
    $sth->finish();

    $dbh->disconnect();

    return $version;
}


package DummyColorUtil;

sub new {
    my $class = shift;
    return bless({}, $class);
}

sub getColorForPfam {
    my $self = shift;
    my $fam = shift;
    return "#888888";
}

1;

