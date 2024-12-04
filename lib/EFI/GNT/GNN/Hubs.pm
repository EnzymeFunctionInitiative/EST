
package EFI::GNT::GNN::Hubs;

use strict;
use warnings;

use List::Util qw(sum);


sub new {
    my $class = shift;
    my %args = @_;

    die "Require EFI::GNT::GNN gnn argument" if not $args{gnn};

    my $self = {};
    bless $self, $class;

    # Map cluster number to Pfams for the cluster
    $self->{cluster_pfam} = {};
    # From EFI::GNT::GNN
    $self->{cluster_data} = {};
    # Cluster-centric GNN hub-spoke data
    $self->{cluster_hubs} = {};
    # Pfam-centric GNN hub-spoke data
    $self->{pfam_hubs} = {};
    # Coocurrence threshold
    $self->{cooc_threshold} = $args{cooc_threshold} // 0.20;

    $self->computeHubsFromGnn($args{gnn});

    return $self;
}


# public
sub compute {
    my $self = shift;
    my $gnn = shift;
    $self->{cluster_data} = $gnn->getClusterData();

    foreach my $clusterNum (keys %{ $self->{cluster_data} }) {
        my $pfamData = {};
        # Maps Pfams of query neighbors to the query ID.  Used to determine the
        # unique list of query IDs within each neighboring Pfam
        my $neighborPfamQuery = {};
        foreach my $query (@{ $self->{cluster_data}->{$clusterNum} }) {
            my $attributes = $query->{attributes};
            my @neighborIds = @{ $query->{neighbors} };
            foreach my $nb (@neighborIds) {
                push @{ $pfamData->{$nb->{pfam}}->{genome_arrangement} },   "$attributes->{id}:$attributes->{direction}:$nb->{id}:$nb->{direction}:$nb->{distance}"; #NOTE: old 'dist'
                push @{ $pfamData->{$nb->{pfam}}->{distances} },            $nb->{distance}; #NOTE: old 'stats'
                push @{ $pfamData->{$nb->{pfam}}->{neighbors_query} },      "$attributes->{id}:$nb->{id}"; #NOTE: old 'neigh'
                push @{ $pfamData->{$nb->{pfam}}->{neighbors} },            $nb->{id}; #NOTE: old 'neighlist'
                $neighborPfamQuery->{$nb->{pfam}}->{$attributes->{id}} = 1; #NOTE old 'orig'
            }
        }
    
        # Get the unique list of query IDs in each neighboring Pfam as well as
        # the list of query IDs in the cluster that have neighbors
        my $hubIdsWithNeighbors = {};
        foreach my $pfam (keys %$neighborPfamQuery) {
            my @ids = sort keys %{ $neighborPfamQuery->{$pfam} };
            #NOTE query_ids is equivalent to the 'orig' output from the old module, except this is
            # unique whereas the old one wasn't
            $pfamData->{$pfam}->{query_ids} = \@ids;
            # $neighborPfamQuery will only contain a Pfam/list of IDs if the query has neighbors
            map { $hubIdsWithNeighbors->{$_} = $pfam } @ids;
        }

        my @hubIdsWithNeighbors = [sort keys %$hubIdsWithNeighbors];
        #NOTE hub_ids is equivalent to the 'withneighbors' output from the old module
        $self->{cluster_pfam}->{$clusterNum} = {pfam => $pfamData, hub_ids => \@hubIdsWithNeighbors};
    }

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
        foreach my $pfam (@pfams) {
            push @{ $pfams{$pfam} }, $clusterNum;
        }
    }

    foreach my $pfam (sort keys %pfams) {
        # Clusters that are associated with this Pfam
        my $clusters = {};

        # Compute the spoke (cluster) nodes that connect to the Pfam hub
        foreach my $clusterNum (@{ $pfams{$pfam} }) {
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
#    $numIdsWithNeighbors - optional; used to reduce number of computations for cluster hubs
#    $numClusterIds - optional; used to reduce number of computations for cluster hubs
#
# Returns:
#    hash ref with keys corresponding to XGMML output attributes
#
sub makeHubData {
    my $self = shift;
    my $clusterNum = shift;
    my $pfamHub = shift;
    my $numIdsWithNeighbors = shift;
    my $numClusterIds = shift;

    $numIdsWithNeighbors = @{ $self->{cluster_pfam}->{$clusterNum}->{hub_ids} } if not defined $numIdsWithNeighbors; #NOTE old 'withneighbors'
    $numClusterIds = @{ $self->{cluster_data}->{$clusterNum} } if not defined $numClusterIds;

    my $numIdsInPfam = @{ $pfamHub->{query_ids} }; #NOTE old 'orig'
    my $cooccurrence = int($numIdsInPfam / $numIdsWithNeighbors * 100) / 100;
    my $coocRatio = "$numIdsInPfam/$numIdsWithNeighbors";
    my $numNeighbors = @{ $pfamHub->{neighbors_query} }; #NOTE old 'neigh'

    my $distanceSum = sum( @{ $pfamHub->{distances} } ); #NOTE old 'stats'
    my $distanceMedian = median( @{ $pfamHub->{distances} } ); #NOTE old 'stats'
    my $averageDist = int( $distanceSum / $numNeighbors * 100 ) / 100;
    my $medianDist = int( $distanceMedian * 100 ) / 100;

    my $data = {
        num_ids_with_neighbors  => $numIdsWithNeighbors, #NOTE old 'withneighbors'
        num_query_ids_in_pfam   => $numIdsInPfam, #NOTE old 'orig'
        num_cluster_ids         => $numClusterIds,
        cooccurrence            => $cooccurrence,
        cooccurrence_ratio      => $coocRatio,
        num_neighbors           => $numNeighbors,
        arrangement             => $pfamHub->{genome_arrangement}, #NOTE old 'dist'
        query_ids_in_pfam       => $pfamHub->{query_ids}, #NOTE old 'orig'
        neighbors               => $pfamHub->{neighbors}, #NOTE old 'neighlist'
        neighbors_query         => $pfamHub->{neighbors_query}, #NOTE old 'neigh'
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
        my $numIdsWithNeighbors = @{ $self->{cluster_pfam}->{$clusterNum}->{hub_ids} };
        my $numClusterIds = @{ $self->{cluster_data}->{$clusterNum} };

        next if $numIdsWithNeighbors < 2;

        # Pfams that are associated with this cluster
        my $pfams = {};

        # Compute the spoke (Pfam) nodes that connect to the cluster hub
        foreach my $pfam (sort keys %{ $self->{cluster_pfam}->{$clusterNum}->{pfam} }) {
            my $pfamHub = $self->{cluster_pfam}->{$clusterNum}->{pfam}->{$pfam};
            my $data = $self->makeHubData($clusterNum, $pfamHub, $numIdsWithNeighbors, $numClusterIds);
            $pfams->{$pfam} = $data;
        }

        $self->{cluster_hubs}->{$clusterNum} = $pfams;
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

    if ($len % 2) { # returns non-zero value if it is not even
        return $vals[int($len / 2)];
    } else {
        return ($vals[int($len / 2) - 1] + $vals[int($len / 2)]) / 2;
    }
}


# public
sub getClusterHubNumbers {
    my $self = shift;
    return sort { $a <=> $b } keys %{ $self->{cluster_hubs} };
}


# public
sub getClusterHub {
    my $self = shift;
    my $clusterNum = shift;
    my $filterSpokes = shift || 1;

    return {} if not $self->{cluster_hubs}->{$clusterNum};

    my $hub = $self->{cluster_hubs}->{$clusterNum};
    return $hub if not $filterSpokes;

    my $filteredSpokes = {};

    foreach my $pfam (keys %$hub) {
        if ($hub->{$pfam}->{cooccurrence} >= $self->{cooc_threshold}) {
            $filteredSpokes->{$pfam} = $hub->{$pfam};
        }
    }

    return $filteredSpokes;
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
    my $filterSpokes = shift || 1;

    return {} if not $self->{pfam_hubs}->{$pfam};

    my $hub = $self->{pfam_hubs}->{$pfam};
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


1;
__END__

=pod

=head1 EFI::GNT::GNN::Hubs

=head2 NAME

B<EFI::GNT::GNN::Hubs> - Perl helper module for computing Pfam and cluster GNN data

=head2 SYNOPSIS

    my $cooccurrenceThreshold = 0.20;
    my $gnn = new EFI::GNT::GNN(...);
    my $hubs = new EFI::GNT::GNN::Hubs(gnn => $gnn, cooc_threshold => $cooccurrenceThreshold);
    $hubs->compute();

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


=head2 METHODS

=head3 C<new(gnn => $gnn, cooc_threshold => $value)>

Creates an object.

=head4 Parameters

=item

=over C<gnn>

A B<EFI::GNT::GNN> object.

=over C<cooc_threshold>

The cooccurrence threshold, used to determine if a cluster hub or Pfam hub should be
included in the output network.  A numerical value > C<0> and <= C<1>.
If not specified, defaults to C<0.20>.

=back

=head4 Example Usage

    my $cooccurrenceThreshold = 0.20;
    my $hubs = new EFI::GNT::GNN::Hubs(gnn => $gnn, cooc_threshold => $cooccurrenceThreshold);


=head3 C<compute()>

Computes hub connectivity for the Pfam and Cluster hub GNNs.  The data used
for computing is obtained from the C<gnn> parameter passed to the constructor.

=head4 Example Usage

    $hubs->compute();


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

A hash ref pointing to an array of hash refs, each with data about a cluster hub.

    {
        {
            "pfam_a" => {
                # Number of query IDs in the cluster that have neighbors with Pfams
                num_query_ids_with_neighbors  => 2,

                # Number of query IDs in the cluster that are in this cluster/Pfam hub ("pfam_a"); size of 'query_ids_in_pfam'
                num_query_ids_in_pfam   => 1,

                # Number of query IDs in the cluster
                num_cluster_ids         => 1,

                # Cooccurrence of Pfam in cluster
                cooccurrence            => 0.4,

                # Cooccurrence expressed in ratio form
                cooccurrence_ratio      => "",

                # Total number of neighbors in the cluster/Pfam
                num_neighbors           => 1,

                # Genome arrangement (direction and distance of neighbors from query IDs in the Pfam)
                arrangement             => [],

                # IDs in the cluster that are in this cluster/Pfam hub ("pfam_a")
                query_ids_in_pfam       => [],

                # IDs of neighbors of each query ID in this cluster/Pfam hub
                neighbors               => [],

                # IDs of neighbors of each query ID in this cluster/Pfam hub, prefixed with the query IDs in the cluster
                neighbors_query         => [],

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
    foreach my $pfam (@$data) {
        print "Pfam $pfam is in cluster 1 and meets the cooccurrence threshold\n";
    }
    # Results in:
    #   Pfam pfam_a is in cluster 1 and meets the cooccurrence threshold

    my $data = $hubs->getClusterHub(1, 0);
    foreach my $pfam (@$data) {
        print "Pfam $pfam is in cluster 1 and may or may not meet the cooccurrence threshold\n";
    }
    # Results in:
    #   Pfam pfam_a is in cluster 1 and may or may not meet the cooccurrence threshold
    #   Pfam pfam_b is in cluster 1 and may or may not meet the cooccurrence threshold


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

A hash ref pointing to two arrays, one with all of the clusters in the
Pfam hub even those that do not meet the cooccurrence threshold, and one that
only contains clusters in the Pfam hub that meet the cooccurrence threshold.

    {
        {
            "1" => {
                # Number of query IDs in the cluster that have neighbors with Pfams
                num_query_ids_with_neighbors  => 2,

                # Number of query IDs in the cluster that are in this cluster/Pfam hub ("pfam_a"); size of 'query_ids_in_pfam'
                num_query_ids_in_pfam   => 1,

                # Number of IDs in the cluster
                num_cluster_ids         => 1,

                # Cooccurrence of Pfam in cluster
                cooccurrence            => 0.4,

                # Cooccurrence expressed in ratio form
                cooccurrence_ratio      => "",

                # Total number of neighbors in the cluster/Pfam
                num_neighbors           => 1,

                # Genome arrangement (direction and distance of neighbors from query IDs in the Pfam)
                arrangement             => [],

                # Query IDs in the cluster that are in this cluster/Pfam hub ("pfam_a")
                query_ids_in_pfam       => [],

                # Query IDs of neighbors of each ID in this cluster/Pfam hub
                neighbors               => [],

                # IDs of neighbors of each query ID in this cluster/Pfam hub, prefixed with the query ID in the cluster
                neighbors_query         => [],

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
    foreach my $cluster (@$data) {
        print "Cluster $cluster is in Pfam hub PF07478-PF1820 and meets the cooccurrence threshold\n";
    }
    # Results in:
    #    Cluster 1 is in Pfam hub PF07478-PF1820 and meets the cooccurrence threshold

    my $data = $hubs->getClusterHub(1, 0);
    foreach my $pfam (@$data) {
        print "Cluster $cluster is in Pfam hub PF07478-PF1820 and may or may not meet the cooccurrence threshold\n";
    }
    # Results in:
    #    Cluster 1 is in Pfam hub PF07478-PF1820 and may or may not meet the cooccurrence threshold
    #    Cluster 2 is in Pfam hub PF07478-PF1820 and may or may not meet the cooccurrence threshold



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


=head3 Return Value Structure

The return structure from C<getClusterHub()> and C<getPfamHub()> is quite large
and is designed to be a summary of the spokes in each hub-spoke model.
Some of the values are self-evident, while others require explanation.  The
C<arrangement>, C<neighbors>, and C<neighbors_query> values are array refs
with the same size.

=over

=item C<num_query_ids_with_neighbors>

The number of query IDs in the Pfam hub that have neighbors.  This may be the
same as C<num_query_ids_in_pfam> but typically is larger.

=item C<num_query_ids_in_pfam>

Number of query IDs in the cluster that are in the cluster/Pfam hub.

=item C<num_cluster_ids>

The number of query IDs in the SSN cluster that the Pfam hub belongs to.

=item C<cooccurrence>

The cooccurrence of the Pfam hub in the cluster (e.g. the number of query IDs
in the Pfam in relation to the number of query IDs with neighbors); given as a
number > C<0> and <= C<1.0>.

=item C<cooccurrence_ratio>

The cooccurrence expressed in ratio form (i.e.
C<num_query_ids_in_pfam / num_query_ids_with_neighbors>) (e.g. C<"33/101">).

=item C<arrangement>

An array that contains the genome arrangement for each neighbor in the spoke.
This is measured by the direction and distance of neighbors from query IDs in
the cluster that are in the Pfam hub.  The format is
C<ID:ID_direction:NEIGHBOR_ID:NEIGHBOR_direction:NEIGHBOR_distance>
and an example is C<B0SS77:-1:B0SS79:1:2> or C<B0SS77:-1:B0SS75:-1:-2>.  The
direction is negative if the gene is in complement form and positive if it is
normal.  The distance is the distance in number of genes from the neighbor
to the query ID.

=item C<query_ids_in_pfam>

An array ref containing a list of query IDs in the cluster-Pfam hub combination.

=item C<neighbors>

An array that contains the neighbor IDs.  For example, C<["B0SS75", "B0SS79"]>.

=item C<neighbors_query>

An array that contains the neighbor IDs prefixed with the query ID.
For example, C<["B0SS77:B0SS75", "B0SS77:B0SS79"]>.

=item C<average_distance>

Average distance of neighbors from query IDs in this cluster/Pfam hub
combination.  For the examples given above, this would be C<2.00>.

=item C<median_distance>

Median distance of neighbors from query IDs in this cluster/Pfam hub
combination.  For the examples given above, this would be C<2.00>.

=back

=cut

