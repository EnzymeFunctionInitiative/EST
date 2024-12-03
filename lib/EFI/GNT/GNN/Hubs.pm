
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

        foreach my $clusterNum (@{ $pfams{$pfam} }) {
            my $pfamHub = $self->{cluster_pfam}->{$clusterNum}->{pfam}->{$pfam};
            my $data = $self->makeHubData($clusterNum, $pfamHub);
            $clusters->{$clusterNum} = $data;
            #TODO: threshold in output, [if ($numIdsWithNeighbors > 1 and $cooccurrence >= $self->{cooc_threshold}) {]
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
        num_ids_in_pfam         => $numIdsInPfam, #NOTE old 'orig'
        num_cluster_ids         => $numClusterIds,
        cooccurrence            => $cooccurrence,
        cooccurrence_ratio      => $coocRatio,
        num_neighbors           => $numNeighbors,
        arrangement             => $pfamHub->{genome_arrangement}, #NOTE old 'dist'
        ids_in_pfam             => $pfamHub->{query_ids}, #NOTE old 'orig'
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

        foreach my $pfam (sort keys %{ $self->{cluster_pfam}->{$clusterNum}->{pfam} }) {
            my $pfamHub = $self->{cluster_pfam}->{$clusterNum}->{pfam}->{$pfam};
            my $data = $self->makeHubData($clusterNum, $pfamHub, $numIdsWithNeighbors, $numClusterIds);
            $pfams->{$pfam} = $data;
            #TODO: threshold in output if ($cooccurrence > $self->{cooc_threshold}) {
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
    my $allClusters = shift || 0;

    return {} if not $self->{cluster_hubs}->{$clusterNum};

    my $data = $self->{cluster_hubs}->{$clusterNum}->{ $allClusters ? "clusters" : "all_clusters" };
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
    return $self->{pfam_hubs}->{$pfam} // {};
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
    my $cluster1Hub = $hubs->getClusterHub($clusterNums[0]);
    
    my $pfamHubNames = $hubs->getPfamHubNames();
    my $pfamHub = $hubs->getPfamHub($pfamHubNames[0]);


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
included in the output network.  A numerical value > 0 and <= 1.  If not specified,
defaults to C<0.20>.

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

Returns the list of cluster hub numbers that are in the GNN.  These are
the same as the cluster numbers in the input network.

=head4 Returns

An array of numerical cluster numbers.

=head4 Example Usage

    my @clusterNums = $hubs->getClusterHubNumbers();
    foreach my $clusterNum (@clusterNums) {
        print "Cluster $clusterNum is in the GNN\n";
    }


=head3 C<getClusterHub($clusterNum, $allClusters)>

Returns cluster hub data for a given cluster number.

=head4 Parameters

=over

=item C<$clusterNum>

Numerical cluster number.

=item C<$allClusters>

If specified and non-zero, then all clusters are returned, even those not meeting
the cooccurrence threshold.  Defaults to 0.

=back

=head4 Returns

A hash ref pointing to an array of hash refs, each with data about a cluster hub.

    [
        {}
        {}
    ]

=head4 Example Usage

    my $data = $hubs->getClusterHub(1);
    foreach my $pfam (@$data) {
        print "Pfam $pfam is in cluster 1 and meets the cooccurrence threshold of 0.20\n";
    }

    my $data = $hubs->getClusterHub(1, 1);
    foreach my $pfam (@$data) {
        print "Pfam $pfam is in cluster 1\n";
    }


=head3 C<getPfamHubNames()>

Returns the list of Pfam hub names that are in the GNN.

=head4 Returns

An array of Pfam hub IDs (can be dash-separated).

=head4 Example Usage

    my @pfams = $hubs->getPfamHubNames();
    foreach my $pfamNum (@pfams) {
        print "Pfam $pfamName is in the GNN\n";
    }


=head3 C<getPfamHub($pfamName)>

Returns Pfam hub data for a given Pfam hub name.

=head4 Parameters

=over

=item C<$pfamName>

Pfam hub name that is in the GNN.

=back

=head4 Returns

A hash ref pointing to two arrays, one with all of the clusters in the
Pfam hub even those that do not meet the cooccurrence threshold, and one that
only contains clusters in the Pfam hub that meet the cooccurrence threshold.

    {
        pfams => [1, 3, ...],
        all_pfams => [1, 2, 3, ...]
    }

=head4 Example Usage

    my $data = $hubs->getPfamHub("PF05544-PF01911");
    foreach my $(@{ $data->{pfams} }) {
        print "Pfam $pfam is in cluster 1 and meets the cooccurrence threshold of 0.20\n";
    }
    foreach my $pfam (@{ $data->{all_clusters} }) {
        print "Pfam $pfam is in cluster 1\n";
    }


=cut

