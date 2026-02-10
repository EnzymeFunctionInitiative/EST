
package EFI::GNT::GND;

use strict;
use warnings;

use DBI;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../..";

use EFI::GNT::GND::Schema qw(:schema);
use EFI::GNT::GND::Uniref;
use EFI::GNT::GND::Util;
use EFI::Sequence::Type qw(:types);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless $self, $class;

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

    $self->{uniref} = new EFI::GNT::GND::Uniref(dbh => $self->{dbh}, db_util => $self->{util});

    my $clusterData = $gnn->getClusterData();

    # Add the UniRef cluster size mapping (e.g. how many UniProt IDs are in the UniRef cluster IDs)
    my ($unirefSizeMapping, $uniref50IdMapping, $uniref90IdMapping);
    if ($networkType ne SEQ_UNIPROT and $args{metanode_mapping}) {
        ($unirefSizeMapping, $uniref50IdMapping, $uniref90IdMapping) = $self->{uniref}->computeUnirefMapping($args{metanode_mapping});
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
        $self->{uniref}->insertUnirefMapping($clusterData, $networkType, $uniref50IdMapping, $uniref90IdMapping, $idIndexMap, $idClusterMap);
    }

    $self->{dbh}->commit();

    my $numIds = scalar keys %$idIndexMap;
    return $numIds;
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

    $self->{util} = new EFI::GNT::GND::Util(dbh => $self->{dbh});

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
#        see EFI::GNT::GND::Uniref::computeUnirefSizeMapping() for format
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
        my $clusterNum = shift;
        my $queryData = $idData->{attributes};
        # Make a copy because we modify it later
        my %queryData = %$queryData;
        $queryData{cluster_index} = $sortKey;
        # Always add uniref size fields; these will be ignored later if the input network is not UniRef
        $queryData{uniref90_size} = $unirefSizeMapping->{$queryData{id}}->{uniref90} // 0;
        $queryData{uniref50_size} = $unirefSizeMapping->{$queryData{id}}->{uniref50} // 0;
        $queryData{&COLOR_COLUMN} = $self->{util}->getColorForPfam($queryData{pfam}, assign_query_gene_color => 1);
        $queryData{cluster_num} = $clusterNum;
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
            my $queryData = $getQueryData->($idData, $clusterNum);

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
        my $nbColor = $self->{util}->getColorForPfam($neighbor->{pfam});
        foreach my $col (@{ $self->{schema}->getNeighborCols() }) {
            next if $col->{primary_key}; # don't insert sort_key for neighbors, since it's auto increment
            if ($col->{name} eq QUERY_KEY or $col->{name} eq LEGACY_QUERY_KEY) {
                push @row, $querySortKey;
            } elsif ($col->{name} eq COLOR_COLUMN) {
                push @row, $nbColor;
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
# insert - private method
#
# Wrapper around helper class.
#
sub insert {
    my $self = shift;
    $self->{util}->insert(@_);
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
    my $numIds = $gnnDb->save($gnn, $dbFile);


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
    my $numIds = $gnnDb->save($gnn, $dbFile);
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

Returns 0 if there was an error or the file exists; otherwise returns the number of IDs written.

=head4 Example Usage

    my $numIdsWritten = $gnnDb->save($gnn, $dbFile);


=head2 SCHEMA

See B<EFI::GNT::GND::Schema> for the database schema.

=cut

