
package EFI::GNT::GNN::Hubs;

use strict;
use warnings;

use List::Util qw(sum);
use Scalar::Util qw(looks_like_number);


use constant NONE_PFAM => "none";
use constant FILTER_COOCCURRENCE => 1;
use constant SKIP_SINGLETONS => 2;
use constant DEFAULT_COOCCURRENCE_THRESHOLD => 0.20;

use Exporter qw(import);
our @EXPORT_OK = qw(NONE_PFAM FILTER_COOCCURRENCE SKIP_SINGLETONS DEFAULT_COOCCURRENCE_THRESHOLD);


sub new {
    my $class = shift;
    my %args = @_;

    die "Require EFI::GNT::GNN gnn argument" if not $args{gnn};
    die "Require seq_cluster_id_map argument" if not $args{seq_cluster_id_map};

    my $self = {};
    bless $self, $class;

    $self->{network} = $args{seq_cluster_id_map};

    # Map cluster number to Pfams for the cluster
    $self->{cluster_pfam} = {};
    # From EFI::GNT::GNN
    $self->{cluster_data} = {};
    # Cluster-centric GNN hub-spoke data
    $self->{cluster_hubs} = {};
    # Pfam-centric GNN hub-spoke data
    $self->{pfam_hubs} = {};
    # Cooccurrence threshold
    $self->{cooc_threshold} = $args{cooc_threshold} // 0.20;
    $self->{no_neighbors} = [];

    if (not exists $args{cooc_threshold} or not looks_like_number($args{cooc_threshold})) {
        $self->{cooc_threshold} = 0.20;
    } elsif ($args{cooc_threshold} >= 0 and $args{cooc_threshold} <= 1) {
        $self->{cooc_threshold} = $args{cooc_threshold};
    } else {
        die "cooc_threshold is outside of range (>= 0 and <= 1)";
    }

    $self->compute($args{gnn});

    return $self;
}


#
# compute - private method
#
# Computes all of the hub data necessary for creating GNNs.
#
# Parameters:
#    $gnn - EFI::GNT::GNN object
#
sub compute {
    my $self = shift;
    my $gnn = shift;

    $self->{cluster_data} = $gnn->getClusterData();
    $self->{cluster_size} = {};
    my @noNeighbors;

    foreach my $clusterNum (keys %{ $self->{cluster_data} }) {
        my $pfamData = {};
        my %queryIdsWithNeighbors;
        $self->{cluster_size}->{$clusterNum} = @{ $self->{network}->{$clusterNum} };
        foreach my $query (@{ $self->{cluster_data}->{$clusterNum} }) {
            my $attributes = $query->{attributes};
            my @neighborIds = @{ $query->{neighbors} };
            push @noNeighbors, $attributes->{id} if not @neighborIds;
            foreach my $nb (@neighborIds) {
                my $data = {
                    id => $nb->{id},
                    direction => $nb->{direction},
                    distance => $nb->{distance},
                };
                my $nbPfam = $nb->{pfam} || NONE_PFAM;
                push @{ $pfamData->{$nbPfam}->{$attributes->{id}} }, $data;
                $queryIdsWithNeighbors{$attributes->{id}} = 1 if $nb->{pfam};
            }
        }
    
        my $numIdsWithNeighbors = scalar keys %queryIdsWithNeighbors;

        #NOTE hub_ids is equivalent to the 'withneighbors' output from the old module
        $self->{cluster_pfam}->{$clusterNum} = {pfam => $pfamData, num_ids_with_neighbors => $numIdsWithNeighbors};
    }

    $self->{no_neighbors} = \@noNeighbors;

    $self->computePfamHubs();
    $self->computeClusterHubs();
}


#
# computePfamHubs - private method
#
# Compute the network with Pfams as the hub nodes and associated clusters as the
# spoke nodes
#
sub computePfamHubs {
    my $self = shift;

    my @clusterNums = sort { $a <=> $b } keys %{ $self->{cluster_pfam} };
    my %pfams;

    foreach my $clusterNum (@clusterNums) {
        my @pfams = keys %{ $self->{cluster_pfam}->{$clusterNum}->{pfam} };
        foreach my $pfam (sort @pfams) {
            push @{ $pfams{$pfam} }, $clusterNum;
        }
    }

    foreach my $pfam (sort keys %pfams) {
        # Clusters that are associated with this Pfam
        my $clusters = {};

        # Compute the spoke (cluster) nodes that connect to the Pfam hub
        foreach my $clusterNum (@{ $pfams{$pfam} }) {
            next if $self->{cluster_pfam}->{$clusterNum}->{num_ids_with_neighbors} < 1;
            my $pfamHub = $self->{cluster_pfam}->{$clusterNum}->{pfam}->{$pfam};
            my $data = $self->makeHubData($clusterNum, $pfamHub);
            $clusters->{$clusterNum} = $data;
        }

        $self->{pfam_hubs}->{$pfam} = $clusters;
    }

}


#
# makeHubData - private method
#
# Creates a data structure for a cluster-Pfam hub combination.
#
# Parameters:
#    $clusterNum - number of the cluster to use to create structure
#    $pfamHub - the hub obtained from the cluster_pfam module variable
#
# Returns:
#    hash ref with keys corresponding to XGMML output attributes
#
sub makeHubData {
    my $self = shift;
    my $clusterNum = shift;
    my $pfamHub = shift;

    my $numClusterIds = $self->{cluster_size}->{$clusterNum};
    my $numIdsWithNeighbors = $self->{cluster_pfam}->{$clusterNum}->{num_ids_with_neighbors};

    my @queryData;
    my @distances;
    foreach my $queryData (@{ $self->{cluster_data}->{$clusterNum} }) {
        my $queryId = $queryData->{attributes}->{id};
        # The ID may exist in the network, but not have genome context information
        if ($pfamHub->{$queryId}) {
            push @queryData, { id => $queryId, neighbors => $pfamHub->{$queryId}, direction => $queryData->{attributes}->{direction} };
            push @distances, map { abs($_->{distance}) } @{ $pfamHub->{$queryId} };
        }
    }

    my $numIdsInPfam = @queryData;
    my $cooccurrence = int($numIdsInPfam / $numIdsWithNeighbors * 100) / 100;
    my $coocRatio = "$numIdsInPfam/$numIdsWithNeighbors";

    my $numNeighbors = @distances;
    my $distanceMedian = median( sort @distances );
    my $distanceSum = sum(@distances);
    my $averageDist = int( $distanceSum / $numNeighbors * 100 ) / 100;
    my $medianDist = int( $distanceMedian * 100 ) / 100;

    my $data = {
        num_ids_with_neighbors  => $numIdsWithNeighbors, #NOTE old 'withneighbors'
        num_query_ids_in_pfam   => $numIdsInPfam, #NOTE old 'orig'
        num_cluster_ids         => $numClusterIds,
        num_neighbors           => $numNeighbors,
        cooccurrence            => $cooccurrence,
        cooccurrence_ratio      => $coocRatio,
        query_ids_in_pfam       => \@queryData,
        average_distance        => sprintf("%.2f", $averageDist),
        median_distance         => sprintf("%.2f", $medianDist),
    };

    return $data;
}


#
# computeClusterHubs - private method
#
# Computes the network with clusters as the hub nodes, and associated Pfams as the
# spoke nodes
#
sub computeClusterHubs {
    my $self = shift;

    my @clusterNums = sort { $a <=> $b } keys %{ $self->{cluster_pfam} };

    foreach my $clusterNum (@clusterNums) {
        next if $self->{cluster_pfam}->{$clusterNum}->{num_ids_with_neighbors} < 1;

        # Neighbor IDs that don't have a Pfam family associated
        my %unclassified;

        # Pfams that are associated with this cluster
        my $pfams = {};

        # Compute the spoke (Pfam) nodes that connect to the cluster hub
        my $clusterPfams = $self->{cluster_pfam}->{$clusterNum}->{pfam};
        foreach my $pfam (sort keys %$clusterPfams) {
            my $pfamHub = $clusterPfams->{$pfam};
            # This will happen when a neighbor doesn't have a Pfam
            if ($pfam eq NONE_PFAM) {
                foreach my $queryId (keys %$pfamHub) {
                    map { $unclassified{$_->{id}} = 1 } @{ $pfamHub->{$queryId} };
                }
                next;
            }

            my $data = $self->makeHubData($clusterNum, $pfamHub);
            $pfams->{$pfam} = $data;
        }

        $self->{cluster_hubs}->{$clusterNum}->{hub} = $pfams;
        $self->{cluster_hubs}->{$clusterNum}->{unclassified} = [keys %unclassified];
    }
}


#
# median - private function
#
# Computes the median of the input list.
#
# Parameters:
#    @vals - list of numeric values
#
# Returns:
#    median value of the input list, a numeric value
#
sub median {
    my @vals = sort {$a <=> $b} @_;
    my $len = @vals;

    if ($len % 2 != 0) {
        return $vals[int($len / 2)];
    } else {
        return ($vals[int($len / 2) - 1] + $vals[int($len / 2)]) / 2;
    }
}


# public
sub getClusterHubNumbers {
    my $self = shift;
    my $skipSingletons = shift // 0;
    my @clusterNums = sort { $a <=> $b } keys %{ $self->{cluster_hubs} };
    @clusterNums = grep { $_ != 0 } @clusterNums if $skipSingletons;
    return @clusterNums;
}


# public
sub getClusterHub {
    my $self = shift;
    my $clusterNum = shift;
    my $filterSpokes = shift // FILTER_COOCCURRENCE;

    my $spokes = { num_ids_with_neighbors => 0, num_cluster_ids => 0, spokes => {} };
    return $spokes if not $self->{cluster_hubs}->{$clusterNum};

    my $hub = $self->{cluster_hubs}->{$clusterNum}->{hub};
    $spokes->{num_ids_with_neighbors} = $self->{cluster_pfam}->{$clusterNum}->{num_ids_with_neighbors};
    $spokes->{num_cluster_ids} = $self->{cluster_size}->{$clusterNum};

    # Return all the spokes if filtering is disabled
    if (not $filterSpokes) {
        $spokes->{spokes} = $hub;
        return $spokes;
    }

    foreach my $pfam (keys %$hub) {
        if ($hub->{$pfam}->{cooccurrence} >= $self->{cooc_threshold}) {
            $spokes->{spokes}->{$pfam} = $hub->{$pfam};
        }
    }

    return $spokes;
}


# public
sub getClusterUnclassified {
    my $self = shift;
    my $clusterNum = shift;
    return [] if not $self->{cluster_hubs}->{$clusterNum};
    return $self->{cluster_hubs}->{$clusterNum}->{unclassified};
}


# public
sub getPfamHubNames {
    my $self = shift;
    return sort keys %{ $self->{pfam_hubs} };
}


# public
sub getPfamHub {
    my $self = shift;
    my $pfam = shift;
    my $filterSpokes = shift // FILTER_COOCCURRENCE;

    return {} if not $self->{pfam_hubs}->{$pfam};

    my $hub = $self->{pfam_hubs}->{$pfam};

    # Return all the spokes if filtering is disabled
    return $hub if not $filterSpokes;

    my $filteredSpokes = {};

    foreach my $clusterNum (keys %$hub) {
        my $spoke = $hub->{$clusterNum};
        if ($spoke->{num_ids_with_neighbors} > 1 and $spoke->{cooccurrence} >= $self->{cooc_threshold}) {
            $filteredSpokes->{$clusterNum} = $spoke;
        }
    }

    return $filteredSpokes;
}


# public
sub getIdsWithNoNeighbors {
    my $self = shift;
    return $self->{no_neighbors};
}


1;
__END__

=pod

=encoding utf8

=head1 EFI::GNT::GNN::Hubs

=head2 NAME

B<EFI::GNT::GNN::Hubs> - Perl helper module for computing Pfam and cluster GNN data

=head2 SYNOPSIS

    my $cooccurrenceThreshold = 0.20;
    my $gnn = new EFI::GNT::GNN(...);
    my $hubs = new EFI::GNT::GNN::Hubs(gnn => $gnn, cooc_threshold => $cooccurrenceThreshold);

    my $clusterNums = $hubs->getClusterHubNumbers();
    my $cluster1Spokes = $hubs->getClusterHub($clusterNums[0]);
    foreach my $pfamHubName (keys %$cluster1Hub) {
        print "Pfam hub $pfamHubName is in $clusterNums[0]\n";
    }
    
    my $pfamHubNames = $hubs->getPfamHubNames();
    my $pfamHub = $hubs->getPfamHub($pfamHubNames[0]);
    foreach my $clusterNum (keys %$pfamHub) {
        print "Cluster number $clusterNum is in Pfam hub $pfamHubNames[0]\n";
    }


=head2 DESCRIPTION

B<EFI::GNT::GNN::Hubs> is a Perl helper module for computing hub data for the Pfam and
cluster hubs.  Data can be retrieved after computation and used by modules such as
B<EFI::GNT::GNN::XgmmlWriter::PfamHub> and B<EFI::GNT::GNN::XgmmlWriter::ClusterHub>.


=head3 Terminology

Terms that will be used throughout this document include:

=over

=item Cluster

A cluster defined in the input SSN.

=item Query ID

A query ID is an ID from the original cluster as opposed to neighbor IDs
which are not in the cluster.

=item Pfam hub

One or more Pfams that have been found in the neighbors; if more than one
Pfam is identified in the neighboring sequences then the family identifiers
are separated by hyphens (e.g. C<"PF07478-PF1820">).

=item Cluster hub

Represents a cluster from the original SSN.

=item Hub node

The central node in a hub-spoke model, representing either a Pfam hub or
a cluster hub.

=item Spoke node

The nodes at the ends of the spokes connected to the hub node, representing
either a Pfam hub or a cluster depending on the GNN.

=item Pfam IDs

The list of query IDs in the original cluster that are associated with a
Pfam hub.  This is determined by grouping together all of the original
query IDs by Pfam hubs determined by the neighboring sequences.

=back


=head2 METHODS

=head3 C<new(gnn =E<gt> $gnn, cooc_threshold =E<gt> $value)>

Creates an object.

=head4 Parameters

=over

=item C<gnn>

A B<EFI::GNT::GNN> object.

=item C<cooc_threshold>

The cooccurrence threshold, used to determine if a cluster hub or Pfam hub should be
included in the output network.  A numerical value E<gt>= C<0> and E<lt>= C<1>.
If not specified, defaults to C<0.20>.

=back

=head4 Example Usage

    my $cooccurrenceThreshold = 0.20;
    my $hubs = new EFI::GNT::GNN::Hubs(gnn =E<gt> $gnn, cooc_threshold => $cooccurrenceThreshold);


=head3 C<getClusterHubNumbers()>

Returns all of the cluster numbers that are in the GNN; no filtering is done
on cooccurrence.

=head4 Returns

An array of numerical cluster numbers.

=head4 Example Usage

    my @clusterNums = $hubs->getClusterHubNumbers();
    foreach my $clusterNum (@clusterNums) {
        print "Cluster $clusterNum is in the GNN\n";
    }


=head3 C<getClusterHub($clusterNum, $filterSpokes)>

Returns Pfam hubs for a given cluster number, optionally filtering out
spoke nodes (Pfam hubs) that have a cooccurrence less than the threshold
provided to C<new()>.

=head4 Parameters

=over

=item C<$clusterNum>

Numerical cluster number.

=item C<$filterSpokes>

If specified and zero, then all clusters are returned, even those not meeting
the cooccurrence threshold.  Optional, and defaults to 1 (filter according to
cooccurrence threshold).

=back

=head4 Returns

A hash ref with a key that points to a hash ref that maps cluster numbers to
cluster data (hash ref) associated with the Pfam hub.  The hash ref also
contains two keys/values containing cluster size information.

    {
        # Number of query IDs in the cluster that have neighbors with Pfams
        num_ids_with_neighbors => 2,

        # Number of query IDs in the cluster
        num_cluster_ids => 2,

        spokes => {
            "pfam_a" => {
                # Number of query IDs in the cluster that have neighbors with Pfams
                num_ids_with_neighbors  => 2,

                # Number of query IDs in the cluster that are in this cluster/Pfam hub ("pfam_a"); size of 'query_ids_in_pfam'
                num_query_ids_in_pfam   => 1,

                # Number of query IDs in the cluster
                num_cluster_ids         => 1,

                # Total number of neighbors in the cluster/Pfam
                num_neighbors           => 1,

                # Cooccurrence of Pfam in cluster
                cooccurrence            => 0.4,

                # Cooccurrence expressed in ratio form
                cooccurrence_ratio      => "",

                # Mapping of query in the Pfam to the neighbors
                query_ids_in_pfam       => [],

                # Average distance of neighbors from query IDs in this cluster/Pfam hub
                average_distance        => "3.00",

                # Median distance of neighbors from query IDs in this cluster/Pfam hub
                median_distance         => "2.00"
            },
            "pfam_b" => {
                ...
                cooccurrence            => 0.1,
                ...
            },
            ...
        }
    }

=head4 Example Usage

    my $data = $hubs->getClusterHub(1);
    foreach my $pfam (keys %{ $data->{spokes} }) {
        print "Pfam $pfam is in cluster 1 and meets the cooccurrence threshold\n";
    }
    # Results in:
    #   Pfam pfam_a is in cluster 1 and meets the cooccurrence threshold

    my $data = $hubs->getClusterHub(1, 0);
    foreach my $pfam (keys %{ $data->{spokes} }) {
        print "Pfam $pfam is in cluster 1 and may or may not meet the cooccurrence threshold\n";
    }
    # Results in:
    #   Pfam pfam_a is in cluster 1 and may or may not meet the cooccurrence threshold
    #   Pfam pfam_b is in cluster 1 and may or may not meet the cooccurrence threshold


=head3 C<getClusterUnclassified($clusterNum)>

Returns the list of neighbor IDs in the given cluster that do not have a Pfam
associated with them.

=head4 Parameters

=over

=item C<$clusterNum>

The cluster number to retrieve the IDs from.

=back

=head4 Returns

An array ref with neighbor accession IDs.

=head4 Example Usage

    my $clusterNum = 4;
    my $ids = $hubs->getClusterUnclassified($clusterNum);
    foreach my $id (@$ids) {
        print "Neighbor ID $id is not classified with a Pfam family\n";
    }


=head3 C<getPfamHubNames()>

Returns all of the Pfam hub names that are in the GNN; no filtering is done
on cooccurrence.

=head4 Returns

An array of Pfam hub names (family IDs, can be hyphen-separated).

=head4 Example Usage

    my @pfams = $hubs->getPfamHubNames();
    foreach my $pfamNum (@pfams) {
        print "Pfam $pfamName is in the GNN\n";
    }


=head3 C<getPfamHub($pfamHubName, $filterSpokes)>

Returns clusters from the given Pfam hub name, optionally filtering out
spoke nodes (clusters) that have a cooccurrence less than the threshold
provided to C<new()>.

=head4 Parameters

=over

=item C<$pfamHubName>

Pfam hub name that is in the GNN.

=item C<$filterSpokes>

If specified and zero, then all clusters are returned, even those not meeting
the cooccurrence threshold.  Optional, and defaults to 1 (filter according to
cooccurrence threshold).

=back

=head4 Returns

A hash ref with a key that points to a hash ref that maps cluster numbers to
Pfam data (hash ref) associated with the cluster.

    {
        spokes => {
            "1" => {
                # Number of query IDs in the cluster that have neighbors with Pfams
                num_ids_with_neighbors  => 2,

                # Number of query IDs in the cluster that are in this cluster/Pfam hub ("pfam_a"); size of 'query_ids_in_pfam'
                num_query_ids_in_pfam   => 1,

                # Number of IDs in the cluster
                num_cluster_ids         => 1,

                # Total number of neighbors in the cluster/Pfam
                num_neighbors           => 1,

                # Cooccurrence of Pfam in cluster
                cooccurrence            => 0.4,

                # Cooccurrence expressed in ratio form
                cooccurrence_ratio      => "",

                # Mapping of query in the Pfam to the neighbors
                query_ids_in_pfam       => [],

                # Average distance of neighbors from query IDs in this cluster/Pfam hub
                average_distance        => "3.00",

                # Median distance of neighbors from query IDs in this cluster/Pfam hub
                median_distance         => "2.00"
            },
            "2" => {
                ...
                cooccurrence            => 0.1,
                ...
            },
            ...
        }
    }

=head4 Example Usage

    my $data = $hubs->getPfamHub("PF07478-PF1820");
    foreach my $cluster (keys %{ $data->{spokes} }) {
        print "Cluster $cluster is in Pfam hub PF07478-PF1820 and meets the cooccurrence threshold\n";
    }
    # Results in:
    #    Cluster 1 is in Pfam hub PF07478-PF1820 and meets the cooccurrence threshold

    my $data = $hubs->getPfamHub("PF07478-PF1820", 0);
    foreach my $cluster (keys %{ $data->{spokes} }) {
        print "Cluster $cluster is in Pfam hub PF07478-PF1820 and may or may not meet the cooccurrence threshold\n";
    }
    # Results in:
    #    Cluster 1 is in Pfam hub PF07478-PF1820 and may or may not meet the cooccurrence threshold
    #    Cluster 2 is in Pfam hub PF07478-PF1820 and may or may not meet the cooccurrence threshold


=head3 C<getIdsWithNoNeighbors()>

Return a list of IDs in the network that exist in the ENA database but do
not have neighbors.

=head4 Returns

An array ref containing IDs that do not have neighbors.

=head4 Example Usage

    my $ids = $hubs->getIdsWithNoNeighbors();
    foreach my $id (@$ids) {
        print "$id has no neighbors\n";
    }


=head2 GNN Concepts

Genome neighborhood networks (GNNs) are generated from sequence similarity
networks (SSNs) by creating networks that show the relationship between
Pfams in sequences that are (genome) neighbors to sequences in SSN clusters.
GNNs are displayed in a hub-spoke model, with each hub representing a Pfam
or cluster (depending on the type of GNN) and each spoke representing
the associated cluster (for Pfam hubs) or Pfam (for cluster hubs).

                        ┌───┐             ┌───┐             
                        │HHH│             │GGG│             
         ┌───┐          └───┘             └───┘             
         │AAA│            xx             xx                 
         └───┘            xx            xx                  
              xxx          xx         xxx                   
                xxx        xx         x                     
                  xxx ┌──────────────┐                      
    ┌───┐             │              │           ┌───┐      
    │BBB│             │              │  xxxxxxxxx│FFF│      
    └───┘ xxxxxxxxxxx │              │xxx        └───┘      
                      │  Cluster X   │                      
                      │              │                      
                      │              │                      
                 xxxx │              │                      
     ┌───┐    xxxx    └──────────────┘                      
     │CCC│xxxx             x        xx                      
     └───┘                xx         xxxx                   
                          x             xxx                 
                          x               x───┐             
                         xx               │EEE│             
                         x                └───┘             
                     ┌───┐                                  
                     │DDD│                                  
                     └───┘                                  

This figure represents a cluster-Pfam hub-spoke GNN, and in a Pfam-cluster
hub-spoke GNN the hub node represents a Pfam and the spoke nodes represent
clusters.  There will be many such hub-spoke models in a GNN.


=head3 Return Value Structure

The return structure from C<getClusterHub()> and C<getPfamHub()> is quite large
and is designed to be a summary of the spokes in each hub-spoke model.
Some of the values are self-evident, while others require explanation.  The
C<arrangement>, C<neighbors>, and C<neighbors_query> values are array refs
with the same size.

=over

=item C<num_ids_with_neighbors>

The number of query IDs in the Pfam hub that have neighbors.  This may be the
same as C<num_query_ids_in_pfam> but typically is larger.

=item C<num_query_ids_in_pfam>

Number of query IDs in the cluster that are in the cluster/Pfam hub.

=item C<num_cluster_ids>

The number of query IDs in the SSN cluster that the Pfam hub belongs to.

=item C<num_neighbors>

The total number of neighbors of all of the queries in the cluster/Pfam hub.

=item C<cooccurrence>

The cooccurrence of the Pfam hub in the cluster (e.g. the number of query IDs
in the Pfam in relation to the number of query IDs with neighbors); given as a
number > C<0> and <= C<1.0>.

=item C<cooccurrence_ratio>

The cooccurrence expressed in ratio form (i.e.
C<num_query_ids_in_pfam / num_ids_with_neighbors>) (e.g. C<"33/101">).

=item C<query_ids_in_pfam>

Array ref that contains hash refs that map query ID in the Pfam hub to the
neighbors of the query.  This looks like:

    [
        {
            id => "query_id",
            direction => 0, # query direction
            neighbors => [
                {
                    id => "neighbor_id",
                    distance => 0, # neighbor distance
                    direction => 0, # neighbor direction
                },
                ...
            ],
        },
        ...
    ]

=item C<average_distance>

Average distance of neighbors from query IDs in this cluster/Pfam hub
combination.  For the examples given above, this would be C<2.00>.

=item C<median_distance>

Median distance of neighbors from query IDs in this cluster/Pfam hub
combination.  For the examples given above, this would be C<2.00>.

=back

=cut

