
package EFI::GNT::GND::Uniref;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../..";

use EFI::Sequence::Type qw(:types);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless $self, $class;

    $self->{dbh} = $args{dbh};
    $self->{db_util} = $args{db_util};

    return $self;
}


#
# insertUnirefMapping
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
    my $idSortFn = $self->makeIdSortFunction($clusterData);

    # Insert UniRef50 tables; each UniRef50 entry points to a list of UniRef90 IDs in the
    # UniRef50 cluster
    if ($networkType eq SEQ_UNIREF50) {
        # $sortUniref50Fn is used to sort all of the IDs in the network first by UniRef50
        # cluster size (e.g. how many UniRef90 IDs are in a UniRef50 cluster).
        # $idSortFn is used to sort UniRef50 IDs within a given network cluster.
        # $sortUniref90Fn is used to sort UniRef90 IDs within a given UniRef50 cluster
        # for when the user "zooms in" on a UniRef50 cluster.
        $self->insertUnirefTables(SEQ_UNIREF50, $sortUniref50Fn, $idSortFn, $sortUniref90Fn, $uniref50IdMapping, $idClusterMap, $idIndexMap);
    }

    # Insert UniRef90 tables; each UniRef90 entry points to a list of UniProt IDs in the
    # UniRef90 cluster
    if ($networkType eq SEQ_UNIREF90 or $networkType eq SEQ_UNIREF50) {
        # $sortUniref90Fn is used to sort all of the IDs in the network first by UniRef90
        # cluster size (e.g. how many UniProt IDs are in a UniRef90 cluster).
        # $idSortFn is used to sort UniRef90 IDs within a given network cluster.
        # The second usage of $idSortFn is used to sort the UniProt IDs within a given
        # UniRef90 cluster for when the user "zooms in" on a UniRef90 cluster.
        $self->insertUnirefTables(SEQ_UNIREF90, $sortUniref90Fn, $idSortFn, $idSortFn, $uniref90IdMapping, $idClusterMap, $idIndexMap);
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
#    $topLevelUnirefSortFn - function that sorts the IDs in $unirefMapping by size
#    $idSortFn - function that sorts the IDs in each network cluster (see
#        makeIdSortFunction for how the sort happens)
#    $unirefClusterSortFn - function that sorts the IDs within a given UniRefXX cluster
#    $unirefMapping - mapping of UniRefXX ID to UniProt IDs in the UniRef cluster
#    $idIndexMap - hash ref mapping sequence ID to the query_key in the network
#    $idClusterMap - hash ref mapping sequence ID to the cluster it belongs in
#
sub insertUnirefTables {
    my $self = shift;
    my $unirefVersion = shift;
    my $topLevelUnirefSortFn = shift;
    my $idSortFn = shift;
    my $unirefClusterSortFn = shift;
    my $unirefMapping = shift;
    my $idClusterMap = shift;
    my $idIndexMap = shift;

    # Create the statement handles that allow parameterized execution of insertions
    my $unirefBase = "uniref" . ($unirefVersion =~ s/\D//gr);
    my $indexSth = $self->{dbh}->prepare("INSERT INTO ${unirefBase}_index (member_index, cluster_index) VALUES (?, ?)");
    my $rangeSth = $self->{dbh}->prepare("INSERT INTO ${unirefBase}_range (uniref_index, uniref_id, start_index, end_index, cluster_index) VALUES (?, ?, ?, ?, ?)");
    my $clusterIndexSth = $self->{dbh}->prepare("INSERT INTO ${unirefBase}_cluster_index (cluster_num, start_index, end_index) VALUES (?, ?, ?)");

    # First sort all of the IDs in the input UniRefXX by the size of the UniRefXX cluster
    my @allUnirefIds = sort $topLevelUnirefSortFn keys %$unirefMapping;

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
            # number of IDs in the UniRef90 cluster, otherwise sorted by the default ID
            # sort function
            @ids = sort $unirefClusterSortFn @ids;

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
                $self->{db_util}->insert($indexSth, [$memberIndex, $clusterIndex]);

                $offset++;
            }

            # Insert the mapping of UniRef index ID
            my $end = $uniprotIndex + $offset - 1;
            $self->{db_util}->insert($rangeSth, [$unirefIndex, $unirefId, $uniprotIndex, $end, $unirefClusterIndex]);

            $uniprotIndex += $offset;
            $unirefIndex++;
        }

        # Insert the mapping of cluster number to UniRef start and end (related to the unirefXX_index table)
        if ($clusterNumIndexMap{$clusterNum}) {
            $self->{db_util}->insert($clusterIndexSth, [$clusterNum, $clusterNumIndexMap{$clusterNum}->{start}, $clusterNumIndexMap{$clusterNum}->{end}]);
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
            # Copy the evalue, or set it to zero if it doesn't exist in the original dataset
            $allIdData->{$id} = { evalue => ($idData->{attributes}->{evalue} // 0) };
        }
    }

    return sub {
        # Parameters $a and $b are accession IDs.  It may be that they are not in the list of
        # in $allIdData IDs; this is because they were collected as part of the reverse mapping
        # that occurred in create_gnns.pl, and we simply compare the accession IDs in this case.
        return $a cmp $b if (not $allIdData->{$a} or not $allIdData->{$b});

        # Compare evalues; non-zero means the values were not equal
        my $comp = $allIdData->{$a}->{evalue} <=> $allIdData->{$b}->{evalue};
        return $comp if $comp;

        # String accession ID comparison
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
# computeUnirefMapping
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


1;

