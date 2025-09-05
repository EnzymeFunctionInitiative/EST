
package EFI::GNT::GND;

use strict;
use warnings;

use DBI;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../..";

use EFI::GNT::GND::Schema qw(:schema);
use EFI::Sequence::Type qw(:types);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless $self, $class;

    # Queue X number of statements before committing (improves performance)
    $self->{insert_count} = 0;
    $self->{insert_max} = 100000;

    return $self;
}


sub save {
    my $self = shift;
    my $gndFile = shift;
    my $gnn = shift;
    my $metadata = shift || {};
    my %args = @_;

    my $networkType = $args{network_type} // SEQ_UNIPROT;

    # Map cluster number to cluster name
    my $clusterNames = \%{ $args{cluster_names} // {} }; # make a copy then create a reference
    # IDs that were matched from FASTA or ID_LOOKUP job types from the GND pipeline
    my $matchedIds = $args{matched_ids} // {};
    my $unmatchedIds = $args{unmatched_ids} // [];

    if (not $self->initializeDatabase($gndFile, $networkType)) {
        return 0;
    }

    my $clusterData = $gnn->getClusterData();

    # Add the UniRef cluster size mapping (e.g. how many UniProt IDs are in the UniRef cluster IDs)
    my ($unirefSizeMapping, $uniref50IdMapping, $uniref90IdMapping);
    if ($networkType ne SEQ_UNIPROT and $args{metanode_mapping}) {
        ($unirefSizeMapping, $uniref50IdMapping, $uniref90IdMapping) = $self->computeUnirefMapping($args{metanode_mapping});
    }

    my $sortSeqIds = $args{sort_sequence_ids} // 0;

    my ($families, $clusterIndex, $idIndexMap, $idClusterMap) = $self->insertClusterData($clusterData, $clusterNames, $sortSeqIds, $unirefSizeMapping);
    $self->insertMetadata($metadata);
    $self->insertFamilies($families);
    $self->insertClusterIndex($clusterIndex);
    $self->insertClusterNames($clusterNames);
    $self->insertUnmatchedIds($unmatchedIds);
    $self->insertMatchedIds($matchedIds);

    if ($networkType ne SEQ_UNIPROT and $uniref50IdMapping and $uniref90IdMapping) {
        $self->insertUnirefMapping($clusterData, $networkType, $uniref50IdMapping, $uniref90IdMapping, $idIndexMap, $idClusterMap);
    }

    $self->{dbh}->commit();

    return 1;
}


#
# initializeDatabase - private method
#
# Connects to a SQLite database (creates if it doesn't exist) and initializes the database
# with the required schema.
#
# Parameters:
#    $gndFile - path to the output GND SQLite file
#    $networkType - type of the input network, e.g. UniProt or UniRef
#
# Returns:
#    0 if failed, non-zero if success
#
sub initializeDatabase {
    my $self = shift;
    my $gndFile = shift;
    my $networkType = shift;

    $self->{dbh} = DBI->connect("DBI:SQLite:dbname=$gndFile", "", "");
    return 0 if not $self->{dbh};

    # Turn on transactions (e.g. don't automatically commit after every insert)
    $self->{dbh}->{AutoCommit} = 0;

    $self->{schema} = new EFI::GNT::GND::Schema(network_type => $networkType, dbh => $self->{dbh});
    return $self->{schema}->initializeDatabase();
}


#
# insertClusterData - private method
#
# Inserts the sequence IDs, associated metadata, neighbors, and obtains information necessary for
# the GND viewer to work.
#
# Parameters:
#    $clusterData - hash ref mapping cluster to sequences and GNN-obtained data
#    $clusterNames - hash ref mapping cluster number to cluster names (e.g. "1" -> "Cluster 1");
#        this is provided so that a default cluster number is set if there is no mapping for a
#        particular cluster
#    $sortSequenceIds - set to true to sort the IDs inside of the cluster alphanumerically; by
#        default IDs are ordered as they exist in the input
#    $unirefSizeMapping - hash ref that maps ID to UniRef sizes; only UniRef IDs will be present,
#        see computeUnirefSizeMapping() for format
#
# Returns:
#    $families - array ref of list of all Pfam and InterPro families that were in the input,
#        including those in neighbors
#    $clusterIndex - hash ref mapping a cluster number to the start/end row index for IDs in the
#        cluster as they are stored in the database
#    $idIndexMap - hash ref mapping sequence ID to the query_key in the network, used for UniRef
#    $idClusterMap - hash ref mapping sequence ID to the cluster it belongs in, used for UniRef
#
sub insertClusterData {
    my $self = shift;
    my $clusterData = shift;
    my $clusterNames = shift;
    my $sortSequenceIds = shift;
    my $unirefSizeMapping = shift // {};

    my $families = {};
    # A unique, sequential number for each query ID
    my $sortKey = 0;
    # Map cluster number to the start and end ID sortKey number
    my $clusterIndex = {};
    # Map sequence ID to the query_key in the network, used for UniRef
    my $idIndexMap = {};
    # Map sequence ID to the cluster it belongs in, used for UniRef
    my $idClusterMap = {};

    # Create a closure for code clarity
    my $getQueryData = sub {
        my $idData = shift;
        my $queryData = $idData->{attributes};
        # Make a copy because we modify it later
        my %queryData = %$queryData;
        $queryData{cluster_index} = $sortKey;
        # Always add uniref size fields; these will be ignored later if the input network is not UniRef
        $queryData{uniref90_size} = $unirefSizeMapping->{$queryData{id}}->{uniref90} // 0;
        $queryData{uniref50_size} = $unirefSizeMapping->{$queryData{id}}->{uniref50} // 0;
        return \%queryData;
    };

    my $sortIdFn = sub { $a->{attributes}->{id} cmp $b->{attributes}->{id} };

    my @clusterNums = sort { $a cmp $b } keys %$clusterData;
    foreach my $clusterNum (@clusterNums) {
        $clusterNames->{$clusterNum} = $clusterNum if not exists $clusterNames->{$clusterNum};
        my $startKey = $sortKey;

        # Get the list of data for each sequence in the cluster, and sort if required
        my @idData = @{ $clusterData->{$clusterNum} };
        @idData = sort $sortIdFn @idData if $sortSequenceIds;

        foreach my $idData (@idData) {
            my $queryData = $getQueryData->($idData);

            $self->insertQueryId($sortKey, $queryData);

            $idIndexMap->{$queryData->{id}} = $sortKey;
            $idClusterMap->{$queryData->{id}} = $clusterNum;

            my $nbFamilies = $self->insertNeighbors($sortKey, $idData->{neighbors});
            $sortKey++;

            map { $families->{$_} = 1 } @$nbFamilies;
            $families->{$idData->{family}} = 1 if $idData->{family};
            $families->{$idData->{ipro_family}} = 1 if $idData->{ipro_family};
        }
        $clusterIndex->{$clusterNum} = [$startKey, $sortKey - 1];
    }

    my @families = sort keys %$families;
    return \@families, $clusterIndex, $idIndexMap, $idClusterMap;
}


#
# insertMatchedIds - private method
#
# Insert the mapping between a UniProt ID and user-provided IDs.  This only occurs if the input
# data originated from an ID list or FASTA file.  There may be more than one user input ID that
# has a match in the UniProt database.
#
# Parameters:
#    $matchedIds - hash ref of UniProt IDs that map to an array ref of user-inputted IDs
#
sub insertMatchedIds {
    my $self = shift;
    my $matchedIds = shift;

    my $sql = "INSERT INTO matched (uniprot_id, id_list) VALUES (?, ?)";
    my $sth = $self->{dbh}->prepare($sql);

    foreach my $id (keys %$matchedIds) {
        my $ids = join(",", @{ $matchedIds->{$id} });
        $sth->execute($id, $ids);
    }

    $self->{dbh}->commit();
}


#
# insertUnmatchedIds - private method
#
# Insert any unmatched IDs into the table that stores the list of unmatched IDs.  This only occurs
# if the input data originated from an ID list or FASTA file, and IDs were included by the user
# that were not matched in the EFI database.
#
# Parameters:
#    $unmatchedIds - array ref of IDs
#
sub insertUnmatchedIds {
    my $self = shift;
    my $unmatchedIds = shift;

    my $sql = "INSERT INTO unmatched (id_list) VALUES (?)";
    my $sth = $self->{dbh}->prepare($sql);

    foreach my $id (@$unmatchedIds) {
        $sth->execute($id);
    }

    $self->{dbh}->commit();
}


#
# insertClusterNames - private method
#
# Insert the table containing a mapping between cluster number and cluster names.  Cluster name
# can be numeric (e.g. same as the cluster number).
#
# Parameters:
#    $clusterNames - hash ref mapping cluster number to cluster name
#
sub insertClusterNames {
    my $self = shift;
    my $clusterNames = shift;

    my $sql = "INSERT INTO cluster_num_map (cluster_num, cluster_id) VALUES (?, ?)";
    my $sth = $self->{dbh}->prepare($sql);

    foreach my $clusterNum (sort { $a cmp $b } keys %$clusterNames) {
        $sth->execute($clusterNum, $clusterNames->{$clusterNum});
    }

    $self->{dbh}->commit();
}


#
# insertClusterIndex - private method
#
# Insert the cluster index table, used for mapping cluster numbers to rows in the database.
#
# Parameters:
#    $clusterIndex - hash ref mapping cluster number to array ref of start/end positions
#
sub insertClusterIndex {
    my $self = shift;
    my $clusterIndex = shift;

    my $sql = "INSERT INTO cluster_index (cluster_num, start_index, end_index) VALUES (?, ?, ?)";
    my $sth = $self->{dbh}->prepare($sql);

    foreach my $clusterNum (sort { $a cmp $b } keys %$clusterIndex) {
        $sth->execute($clusterNum, $clusterIndex->{$clusterNum}->[0], $clusterIndex->{$clusterNum}->[1]);
    }

    $self->{dbh}->commit();
}


#
# insertUnirefMapping - private method
#
# Insert the various UniRef mapping tables necessary to view UniRef organized data in the
# GND viewer.
#
# Parameters:
#    $clusterData - hash ref mapping cluster to sequences and GNN-obtained data
#    $networkType - one of SEQ_UNIPROT, SEQ_UNIREF50, or SEQ_UNIREF90
#    $uniref50IdMapping - hash ref mapping UniRef50 sequence IDs to UniRef90 IDs within
#        the UniRef50 cluster
#    $uniref90IdMapping - hash ref mapping UniRef90 sequence IDs to UniProt IDs within
#        the UniRef90 cluster
#    $idIndexMap - hash ref mapping sequence ID to the query_key in the network
#    $idClusterMap - hash ref mapping sequence ID to the cluster it belongs in
#
# Remarks:
#
# The sequences are sorted in the following order for a UniRef50 network:
#
#     cluster_1:
#         (ids sorted alphabetically)
#         uniref50_a:
#             (sorted by uniref90 cluster size)
#             uniref90_d: [size 4]
#                 (sorted alphabetically, or if source is BLAST, by e-value)
#                 uniprot_a
#                 uniprot_b
#                 uniprot_c
#                 uniprot_d
#             uniref90_a: [size 2]
#                 uniprot_e
#                 uniprot_f
#             uniref90_b: [size 1]
#                 uniprot_g
#         uniref50_b:
#             ...
#         uniref50_c:
#             ...
#     cluster_2:
#         ...
#     ...
#
# For a UniRef90 network:
#
#     cluster_1:
#         (ids sorted alphabetically)
#         uniref90_a:
#             (sorted alphabetically, or if source is BLAST, by e-value)
#             uniprot_e
#             uniprot_f
#         uniref90_d:
#             uniprot_a
#             uniprot_b
#             uniprot_c
#             uniprot_d
#         ...
#     cluster_2:
#         ...
#     ...
#
sub insertUnirefMapping {
    my $self = shift;
    my $clusterData = shift;
    my $networkType = shift;
    my $uniref50IdMapping = shift;
    my $uniref90IdMapping = shift;
    my $idIndexMap = shift;
    my $idClusterMap = shift;

    my $sortUniref50Fn = $self->makeUnirefSizeSortFunction($uniref50IdMapping);
    my $sortUniref90Fn = $self->makeUnirefSizeSortFunction($uniref90IdMapping);
    my $defaultIdSortFn = $self->makeIdSortFunction($clusterData);

    # Insert UniRef50 tables; each UniRef50 entry points to a list of UniRef90 IDs in the
    # UniRef50 cluster
    if ($networkType eq SEQ_UNIREF50) {
        # The sortUniref50Fn tells the code to sort the all of the IDs in the network first
        # by UniRef50 cluster size (e.g. how many UniRef90 IDs are in a UniRef50 cluster).
        # defaultIdSortFn is how UniRef50 IDs are sorted within a given network cluster.
        # We also pass the sortUniref90Fn sort function so that the UniRef90 IDs in the
        # UniRef50 cluster are sorted by UniRef90 cluster size.
        $self->insertUnirefTables(SEQ_UNIREF50, $sortUniref50Fn, $defaultIdSortFn, $uniref50IdMapping, $idClusterMap, $idIndexMap, $sortUniref90Fn);
    }

    # Insert UniRef90 tables; each UniRef90 entry points to a list of UniProt IDs in the
    # UniRef90 cluster
    if ($networkType eq SEQ_UNIREF90 or $networkType eq SEQ_UNIREF50) {
        # If the network is UniRef90, then sort the outer IDs (e.g. UniRef90 IDs) in the
        # network cluster by UniRef90 ID.  If the network is UniRef50, then we sort the
        # UniRef90 tables by the UniRef90 cluster size.
        my $idSortFn = $networkType eq SEQ_UNIREF90 ? $defaultIdSortFn : $sortUniref90Fn;
        $self->insertUnirefTables(SEQ_UNIREF90, $sortUniref90Fn, $idSortFn, $uniref90IdMapping, $idClusterMap, $idIndexMap);
    }
}


#
# insertUnirefTables - private method
#
# Insert the three tables necessary to support visualization of GND entries grouped by
# UniRef clusters.  IDs are first grouped and sorted by UniRef cluster size, then three
# tables are created (this is repeated for both UniRef50 and UniRef90):
#
#     # maps all of the UniProt IDs in the UniRef IDs to the cluster_index column in the
#     # 'attributes' table; this is necessary so that blocks of UniRef IDs can be
#     # retrieved--related to the unirefXX_range table
#     unirefXX_index:
#         member_index: sequential index ID corresponding to a UniProt ID
#         cluster_index: cluster_index value for UniProt ID in 'attributes' table
#
#     # maps a UniRef ID to blocks of UniProt IDs as defined in unirefXX_index; this
#     # allows to select a subset of IDs to asynchronously retrieve data in the UI
#     unirefXX_range:
#         uniref_index: sequential index ID for a UniRef ID
#         uniref_id: UniRef accession ID
#         start_index: start of a range of member_index values in unirefXX_index
#         end_index: end of a range of member_index values in unirefXX_index
#         cluster_index: cluster_index value for the UniRef ID in 'attributes' table
#
#     # maps a network cluster number to a range of UniRef index IDs
#     unirefXX_cluster_index
#         cluster_num: network cluster number
#         start_index: the start of the block of UniRef index IDs (uniref_index) in
#             unirefXX_range corresponding to the UniRef IDs in the cluster
#         end_index: the end of the block of UniRef index IDs (uniref_index) in
#             unirefXX_range corresponding to the UniRef IDs in the cluster
#
# Parameters:
#    $unirefVersion - SEQ_UNIREF50 or SEQ_UNIREF90
#    $unirefClusterSizeSortFn - function that sorts the IDs in $unirefMapping by size
#    $idSortFn - function that sorts the IDs in each cluster
#    $unirefMapping - mapping of UniRefXX ID to UniProt IDs in the UniRef cluster
#    $idIndexMap - hash ref mapping sequence ID to the query_key in the network
#    $idClusterMap - hash ref mapping sequence ID to the cluster it belongs in
#    $sortClustersByUniref90SizeFn - if present, the IDs in each UniRefXX cluster are
#        sorted by this function before being saved (used to save UniRef90 IDs by size
#        in UniRef50 mapping tables)
#
sub insertUnirefTables {
    my $self = shift;
    my $unirefVersion = shift;
    my $unirefClusterSizeSortFn = shift;
    my $idSortFn = shift;
    my $unirefMapping = shift;
    my $idClusterMap = shift;
    my $idIndexMap = shift;
    my $sortClustersByUniref90SizeFn = shift || 0;

    # Create the statement handles that allow parameterized execution of insertions
    my $unirefBase = "uniref" . ($unirefVersion =~ s/\D//gr);
    my $indexSth = $self->{dbh}->prepare("INSERT INTO ${unirefBase}_index (member_index, cluster_index) VALUES (?, ?)");
    my $rangeSth = $self->{dbh}->prepare("INSERT INTO ${unirefBase}_range (uniref_index, uniref_id, start_index, end_index, cluster_index) VALUES (?, ?, ?, ?, ?)");
    my $clusterIndexSth = $self->{dbh}->prepare("INSERT INTO ${unirefBase}_cluster_index (cluster_num, start_index, end_index) VALUES (?, ?, ?)");

    # First sort all of the IDs in the input UniRefXX by the size of the UniRefXX cluster
    my @allUnirefIds = sort $unirefClusterSizeSortFn keys %$unirefMapping;

    # Now get all of the network clusters and the UniRefXX IDs in the cluster (exclude singletons)
    my %networkClusters;
    map { push @{ $networkClusters{ $idClusterMap->{$_} } }, $_ if $idClusterMap->{$_} } @allUnirefIds;

    # This is a unique index ID for the UniRef index ID in the range table, used to map
    # a UniRef index ID to a list of UniProt index IDs
    my $unirefIndex = 0;

    # This is a unique index ID for each UniProt ID, used to map an entry in the
    # UniRef index ID table to the attributes UniProt table (using the cluster_index field
    # in the attributes table)
    my $uniprotIndex = 0;

    my %clusterNumIndexMap;

    # Process each network cluster, sorted in size by largest to smallest
    foreach my $clusterNum (sort { $a <=> $b } keys %networkClusters) {
        my @unirefIds = sort $idSortFn @{ $networkClusters{$clusterNum} };

        # Use this to map a network cluster number to a list of UniRef index IDs
        my $startUnirefIndex = $unirefIndex;

        foreach my $unirefId (@unirefIds) {
            my $unirefClusterIndex = $idIndexMap->{$unirefId};
            # This UniRef ID was retrieved due to a reverse lookup in a previous step, but does
            # not have ENA data associated with it, so skip
            next if not defined $unirefClusterIndex;

            # If this insertion is for UniRef50 tables, then these IDs are UniRef90 IDs
            my @ids = @{ $unirefMapping->{$unirefId} };

            # If this insertion is for UniRef50 tables, then sort the UniRef90 IDs by the
            # number of IDs in the UniRef90 cluster
            if ($sortClustersByUniref90SizeFn) {
                @ids = sort $sortClustersByUniref90SizeFn @ids;
            }

            # This represents a sequential index ID into the list of @ids
            my $offset = 0;

            foreach my $id (@ids) {
                # This maps the UniRef ID to the cluster_index column in the attributes table
                my $clusterIndex = $idIndexMap->{$id};
                # The UniProt ID may be in a different cluster
                my $idClusterNum = $idClusterMap->{$id};

                # This UniRef90 ID was retrieved due to a reverse lookup in a previous step,
                # but does not have ENA data associated with it, so skip
                next if not defined $clusterIndex;

                # Save the start and end UniRef index ID for the cluster
                $clusterNumIndexMap{$clusterNum}->{start} = $startUnirefIndex if not exists $clusterNumIndexMap{$clusterNum}->{start};
                $clusterNumIndexMap{$clusterNum}->{end} = $unirefIndex;

                # Insert the mapping of ID index to UniProt cluster_index
                my $memberIndex = $uniprotIndex + $offset;
                $self->insert($indexSth, [$memberIndex, $clusterIndex]);

                $offset++;
            }

            # Insert the mapping of UniRef index ID
            my $end = $uniprotIndex + $offset - 1;
            $self->insert($rangeSth, [$unirefIndex, $unirefId, $uniprotIndex, $end, $unirefClusterIndex]);

            $uniprotIndex += $offset;
            $unirefIndex++;
        }

        # Insert the mapping of cluster number to UniRef start and end (related to the unirefXX_index table)
        if ($clusterNumIndexMap{$clusterNum}) {
            $self->insert($clusterIndexSth, [$clusterNum, $clusterNumIndexMap{$clusterNum}->{start}, $clusterNumIndexMap{$clusterNum}->{end}]);
        }
    }
}


#
# makeIdSortFunction - private method
#
# Make a function that is used to sort IDs (that are in a cluster) by BLAST evalue (only valid
# if the original job was from BLAST), then by accession ID.  In the future other sort criteria
# could be added here.
#
# Parameters:
#    $clusterData - hash ref mapping cluster to sequences and GNN-obtained data
#
# Returns:
#    code reference that is used in a sort call
#
sub makeIdSortFunction {
    my $self = shift;
    my $clusterData = shift;

    # Obtain all of the IDs and metadata so we can compare by ID without knowing anything about
    # the cluster.  We need to do this because $clusterData organizes IDs by clusters which won't
    # work in the sort.
    my $allIdData = {};
    foreach my $clusterNum (keys %$clusterData) {
        foreach my $idData (@{ $clusterData->{$clusterNum} }) {
            my $id = $idData->{attributes}->{id};
            $allIdData->{$id} = { evalue => $idData->{attributes}->{evalue} // 0 };
        }
    }

    return sub {
        # Parameters $a and $b are accession IDs
        my $comp = $allIdData->{$a}->{evalue} <=> $allIdData->{$b}->{evalue};
        return $comp if $comp;
        return $a cmp $b;
    };
}


#
# makeUnirefSizeSortFunction - private method
#
# Make a function that is used to sort UniRef clusters by the size of the cluster.  This
# is used so that the contents of a UniRef cluster, when zoomed in (e.g. when a UniRef50
# ID is clicked on), is sorted by the size of the cluster.
#
# Parameters:
#    $unirefMapping - Mapping of UniRef ID to list of UniProt IDs in the cluster
#
# Returns:
#    code reference that is used in a sort call
#
sub makeUnirefSizeSortFunction {
    my $self = shift;
    my $unirefMapping = shift;

    return sub {
        my $comp = scalar @{ $unirefMapping->{$b} } <=> scalar @{ $unirefMapping->{$a} };
        return $comp if $comp;
        return $a cmp $b;
    };
}


#
# insertFamilies - private method
#
# Insert a list of families into the families table.
#
# Parameters:
#    $families - array ref of all families, Pfam and InterPro
#
sub insertFamilies {
    my $self = shift;
    my $families = shift;

    my $sql = "INSERT INTO families (family) VALUES (?)";
    my $sth = $self->{dbh}->prepare($sql);

    foreach my $fam (sort @$families) {
        $sth->execute($fam);
    }

    $self->{dbh}->commit();
}


#
# insertMetadata - private method
#
# Inserts metadata into the metadata table.  Available values are cooccurrence,
# neighborhood_size, title, type, sequence.
#
# Parameters:
#    $metadata - hash ref with one or more of the keys above
#
sub insertMetadata {
    my $self = shift;
    my $metadata = shift;

    my @cols;
    my @ph;
    my @vals;

    my @mdKeys = ("cooccurrence", "neighborhood_size", "name", "type", "sequence", "network_type");
    foreach my $mdKey (@mdKeys) {
        if (exists $metadata->{$mdKey}) {
            push @cols, $mdKey;
            push @vals, $metadata->{$mdKey};
        }
    }

    if (@cols) {
        my $ph = join(", ", map "?", 0..$#cols);
        my $cols = join(", ", @cols);
        my $sql = "INSERT INTO metadata ($cols) VALUES($ph)";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute(@vals);
        $self->{dbh}->commit();
    }
}


#
# insertNeighbors - private method
#
# Inserts all the neighbors for a given query.
#
# Parameters:
#    $querySortKey - the attribute (query) table sort key ID
#    $neighbors - array ref of neighbors
#
# Returns:
#    an array ref with a list of all the families in the neighbors
#
sub insertNeighbors {
    my $self = shift;
    my $querySortKey = shift;
    my $neighbors = shift;
    my $sortKey = 0;

    if (not $self->{insert_neighbor_sth}) {
        my @cols = map { $_->{db_name} // $_->{name} } grep { not $_->{primary_key} } @{ $self->{schema}->getNeighborCols() };
        my @vals = map { "?" } @cols;

        my $colNames = join(", ", @cols);
        my $vals = join(", ", @vals);
        my $sql = "INSERT INTO " . NEIGHBOR_TABLE . " ($colNames) VALUES ($vals)";

        my $sth = $self->{dbh}->prepare($sql);
        if (not $sth) {
            die "Error preparing SQL query for inserting neighbors ($sql)";
        }
        $self->{insert_neighbor_sth} = $sth;
    }

    my %families;
    foreach my $neighbor (@$neighbors) {
        my @row;
        foreach my $col (@{ $self->{schema}->getNeighborCols() }) {
            next if $col->{primary_key}; # don't insert sort_key for neighbors, since it's auto increment
            if ($col->{name} eq QUERY_KEY or $col->{name} eq LEGACY_QUERY_KEY) {
                push @row, $querySortKey;
            } else {
                push @row, $neighbor->{$col->{name}} // "";
            }
        }

        $families{$neighbor->{family}} = 1 if $neighbor->{family};
        $families{$neighbor->{ipro_family}} = 1 if $neighbor->{ipro_family};
        $self->insert($self->{insert_neighbor_sth}, \@row);
    }

    return [keys %families];
}


#
# insertQueryId - private method
#
# Inserts a query row into the database.
#
# Parameters:
#    $sortKey - a unique number that corresponds to the query sequence
#    $queryData - attributes that are associated with the query
#
sub insertQueryId {
    my $self = shift;
    my $sortKey = shift;
    my $queryData = shift;

    my @row;
    foreach my $col (@{ $self->{schema}->getQueryIdCols() }) {
        push @row, $queryData->{$col->{name}} // "";
    }

    if (not $self->{insert_query_sth}) {
        my @cols = map { $_->{db_name} // $_->{name} } @{ $self->{schema}->getQueryIdCols() };
        my @vals = map { "?" } @cols;

        my $colNames = join(", ", @cols);
        my $vals = join(", ", @vals);
        my $sql = "INSERT INTO " . QUERY_TABLE . " ($colNames) VALUES ($vals)";

        my $sth = $self->{dbh}->prepare($sql);
        if (not $sth) {
            die "Error preparing SQL query for inserting queries ($sql)";
        }
        $self->{insert_query_sth} = $sth;
    }


    # Add NULL at the start to get auto increment
    shift @row;
    unshift @row, $sortKey;

    $self->insert($self->{insert_query_sth}, \@row);
}


#
# computeUnirefMapping - private method
#
# Computes the mapping of UniRef ID to UniProt IDs within the UniRef cluster as well as the
# size of the UniRef cluster.
#
# Parameters:
#    $mapping - metanode map that comes from the pipeline
#
# Returns:
#    sizes - hash ref mapping UniRef ID to size ($size->{id} may contain either a key for
#        uniref90 or uniref50 that points to a numeric value
#    uniref50Ids - hash ref mapping a UniRef50 ID to the UniRef90 IDs within the UniRef50
#        cluster
#    uniref90Ids - hash ref mapping a UniRef90 ID to the UniProt IDs within the cluster
#
sub computeUnirefMapping {
    my $self = shift;
    my $mapping = shift;

    my %uniref90Ids;
    my %uniref50Ids;
    my %uniref50to90Ids;

    # Compute the mapping of UniRef90 IDs to UniProt
    foreach my $uniprotId (keys %$mapping) {
        push @{ $uniref90Ids{ $mapping->{$uniprotId}->{uniref90} } }, $uniprotId;
        # The mapping of the UniRef50 ID to UniRef90 IDs 
        $uniref50to90Ids{ $mapping->{$uniprotId}->{uniref50} }->{ $mapping->{$uniprotId}->{uniref90} }++;
    }

    # Compute the mapping of UniRef50 IDs to UniRef90 IDs 
    foreach my $uniref50Id (keys %uniref50to90Ids) {
        foreach my $uniref90Id (keys %{ $uniref50to90Ids{$uniref50Id} }) {
            push @{ $uniref50Ids{$uniref50Id} }, $uniref90Id;
        }
    }

    my $sizes = {};

    foreach my $uniref90Id (keys %uniref90Ids) {
        $sizes->{$uniref90Id}->{uniref90} = @{ $uniref90Ids{$uniref90Id} };
    }

    foreach my $uniref50Id (keys %uniref50Ids) {
        $sizes->{$uniref50Id}->{uniref50} = @{ $uniref50Ids{$uniref50Id} };
    }

    return $sizes, \%uniref50Ids, \%uniref90Ids;
}


#
# insert - private method
#
# Inserts data into a table.  Insertions are done in a transaction
# to improve performance.  Uses parameterized insertions to perform
# data validation.
#
# Parameters:
#    $sth - statement handle corresponding to the table that data
#        will be inserted into; the statement handle is created once
#        for performance reasons (so prepare isn't run every time
#        we insert)
#    $row - array ref of row values as database parameters
#
sub insert {
    my $self = shift;
    my $sth = shift;
    my $row = shift;
    # Commit the transaction if we've reached a certain number of statments
    if (++$self->{insert_count} % $self->{insert_max} == 0) {
        $self->{insert_count} = 0;
        $self->{dbh}->commit();
    }
    $sth->execute(@$row);
}


1;
__END__

=pod

=head1 EFI::GNT::GND

=head2 NAME

B<EFI::GNT::GND> - Perl module for writing genome neighborhood diagram database files

=head2 SYNOPSIS

    # Perform $gnn computations and save data
    my $gnn = new EFI::GNT::GNN(...);

    my $dbFile = "gnn_db.sqlite";
    my $gnnDb = new EFI::GNT::GND();
    $gnnDb->save($gnn, $dbFile);


=head2 DESCRIPTION

B<EFI::GNT::GND> is a Perl module for writing genome neighborhood diagram data
to SQLite database files.  The data that is stored and retrieved comes from
B<EFI::GNT::GNN>.


=head2 METHODS

=head3 C<new()>

Creates a new B<EFI::GNT::GND> instance.

=head4 Example Usage

    my $dbFile = "gnn_db.sqlite";
    my $gnnDb = new EFI::GNT::GND();
    $gnnDb->save($gnn, $dbFile);
    # gnn_db.sqlite will now exist in the current directory


=head3 C<save($gnn, $dbFile)>

Saves data from the given GNN into the database file.  If the file exists
then the existing data is overwritten.

=head4 Parameters

=over

=item C<$gnn>

A reference to a B<EFI::GNT::GNN> object; the GNN data in C<$gnn> should have
already been retrieved.

=item C<$dbFile>

The path to a GND file to create.

=back

=head4 Returns

Returns 0 if there was an error or the file exists; 1 otherwise.

=head4 Example Usage

    $gnnDb->save($gnn, $dbFile);


=head2 SCHEMA

See B<EFI::GNT::GND::Schema> for the database schema.

=cut

