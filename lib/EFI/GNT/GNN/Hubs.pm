
package EFI::GNT::GNN::Hubs;

use strict;
use warnings;


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


#TODO: documentation
sub compute {
    my $self = shift;
    my $gnn = shift;
    $self->{cluster_data} = $gnn->getClusterData();

    # internal structure looks like this:
    #   cluster_pfam => {
    #       "cluster_num" => {
    #           pfams => {
    #               "pfam_id" => {
    #                   query_ids => [],
    #                   genome_arrangement => [],
    #                   distances => [],
    #                   neighbors_query => [],
    #                   neighbors => [],
    #               },
    #               "pfam_id2" => {
    #                   ...
    #               },
    #               ...
    #           },
    #           # IDs in the cluster that have neighbors
    #           hub_ids => [
    #               "query",
    #               "query",
    #               ...
    #           ] 
    #       }
    #   }
    #
    # The pfams associated with the cluster_num in this structure are Pfams
    # from the neighbors not the query.
    #

    foreach my $clusterNum (keys %{ $self->{cluster_data} }) {
        my $pfamData = {};
        # Maps Pfams of query neighbors to the query ID.  Used to determine the
        # unique list of query IDs within each neighboring Pfam
        my $neighborPfamQuery = {};
        foreach my $query (@{ $self->{cluster_data}->{$clusterNum} }) {
            my $attributes = $query->{attributes};
            my @neighborIds = @{ $query->{neighbors} };
            foreach my $nb (@neighborIds) {
                push @{ $pfamData->{$nb->{pfam}}->{genome_arrangement} }, "$attributes->{id}:$attributes->{direction}:$nb->{id}:$nb->{direction}:$nb->{distance}";
                push @{ $pfamData->{$nb->{pfam}}->{distances} }, $nb->{distance};
                push @{ $pfamData->{$nb->{pfam}}->{neighbors_query} }, "$attributes->{id}:$nb->{id}";
                push @{ $pfamData->{$nb->{pfam}}->{neighbors} }, $nb->{id};
                $neighborPfamQuery->{$nb->{pfam}}->{$attributes->{id}} = 1;
            }
        }
    
        # Get the unique list of query IDs in each neighboring Pfam as well as
        # the list of query IDs in the cluster that have neighbors
        my $hubIdsWithNeighbors = {};
        foreach my $pfam (keys %$neighborPfamQuery) {
            my @ids = keys %{ $neighborPfamQuery->{$pfam} };
            $pfamData->{$pfam}->{query_ids} = [sort @ids];
            # $neighborPfamQuery will only contain a Pfam/list of IDs if the query has neighbors
            map { $hubIdsWithNeighbors->{$_} = $pfam } @ids;
        }

        my @hubIdsWithNeighbors = [sort keys %$hubIdsWithNeighbors];
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

    # internal structure looks like this:
    #   pfam_hubs => {
    #       "pfam" => {
    #           "cluster_num" => {
    #               num_queries_with_neighbors => 0,
    #               num_ids_in_pfam => 0,
    #               cooccurrence => 0,
    #           },
    #           "cluster_num" => {
    #               num_queries_with_neighbors => 0,
    #               num_ids_in_pfam => 0,
    #               cooccurrence => 0,
    #           },
    #       }
    #   }

    foreach my $pfam (sort keys %pfams) {
        # Clusters that are associated with this Pfam
        my $clusters = {};

        foreach my $clusterNum (@{ $pfams{$pfam} }) {
            my $numQueriesWithNeighbors = @{ $self->{cluster_pfam}->{$clusterNum}->{hub_ids} };
            my $numIdsInPfam = @{ $self->{cluster_pfam}->{$clusterNum}->{pfam}->{$pfam}->{query_ids} };
            my $numClusterIds = @{ $self->{cluster_data}->{$clusterNum} };
            my $cooccurrence = int($numQueriesWithNeighbors / $numIdsInPfam * 100) / 100;

            my $data = {
                num_queries_with_neighbors => $numQueriesWithNeighbors,
                num_ids_in_pfam => $numIdsInPfam,
                num_cluster_ids => $numClusterIds,
                cooccurrence => $cooccurrence,
            };

            $clusters->{$clusterNum} = $data;
            #TODO: threshold in output, [if ($numQueriesWithNeighbors > 1 and $cooccurrence >= $self->{cooc_threshold}) {]
        }

        $self->{pfam_hubs}->{$pfam} = $clusters;
    }

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

    # internal structure that is stored looks like this:
    #   cluster_hubs => {
    #       "cluster_num" => {
    #           "pfam" => {
    #               ...
    #            },
    #           "pfam" => {
    #               ...
    #            },
    #       },
    #       "cluster_num" => {
    #           "pfam" => {
    #               ...
    #            },
    #           "pfam" => {
    #               ...
    #            },
    #       },
    #   }

    foreach my $clusterNum (@clusterNums) {
        my $numQueriesWithNeighbors = @{ $self->{cluster_pfam}->{$clusterNum}->{hub_ids} };
        my $numClusterIds = @{ $self->{cluster_data}->{$clusterNum} };

        next if $numQueriesWithNeighbors < 2;

        # Pfams that are associated with this cluster
        my $pfams = {};

        foreach my $pfam (sort keys %{ $self->{cluster_pfam}->{$clusterNum}->{pfam} }) {
            my $numIdsInPfam = @{ $self->{cluster_pfam}->{$clusterNum}->{pfam}->{$pfam}->{query_ids} };
            my $cooccurrence = int($numIdsInPfam / $numQueriesWithNeighbors * 100) / 100;
            my $data = {
                num_queries_with_neighbors => $numQueriesWithNeighbors,
                num_ids_in_pfam => $numIdsInPfam,
                num_cluster_ids => $numClusterIds,
                cooccurrence => $cooccurrence,
            };
            $pfams->{$pfam} = $data;
            #TODO: threshold in output if ($cooccurrence > $self->{cooc_threshold}) {
        }

        $self->{cluster_hubs}->{$clusterNum} = $pfams;
    }
}


sub getClusterHubNumbers {
    my $self = shift;
    return sort { $a <=> $b } keys %{ $self->{cluster_hubs} };
}


sub getClusterHub {
    my $self = shift;
    my $clusterNum = shift;
    my $allClusters = shift || 0;

    return {} if not $self->{cluster_hubs}->{$clusterNum};

    my $data = $self->{cluster_hubs}->{$clusterNum}->{ $allClusters ? "clusters" : "all_clusters" };
}


sub getPfamHubNames {
    my $self = shift;
    return sort keys %{ $self->{pfam_hubs} };
}


sub getPfamHub {
    my $self = shift;
    my $pfam = shift;
    return $self->{pfam_hubs}->{$pfam} // {};
}


1;
__END__

=pod


=head3 C<getClusterHubNumbers()>

Returns the list of cluster hub numbers that are in the GNN.  These are
the same as the cluster numbers in the input network.

=head4 Returns

An array of numerical cluster numbers

=head4 Example Usage

    my @clusterNums = $hubs->getClusterHubNumbers();
    foreach my $clusterNum (@clusterNums) {
        print "Cluster $clusterNum is in the GNN\n";
    }


=head3 C<getClusterHub($clusterNum, $allClusters)>

Returns cluster hub data for a given cluster number

=head4 Parameters

=over

=item C<$clusterNum>

Numerical cluster number

=item C<$allClusters>

If specified and non-zero, then all clusters are returned, even those not meeting
the cooccurrence threshold.  Defaults to 0

=back

=head4 Returns

A hash ref pointing to an array of hash refs, each with data about a cluster hub

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

Returns the list of Pfam hub names that are in the GNN

=head4 Returns

An array of Pfam hub IDs (can be dash-separated)

=head4 Example Usage

    my @pfams = $hubs->getPfamHubNames();
    foreach my $pfamNum (@pfams) {
        print "Pfam $pfamName is in the GNN\n";
    }


=head3 C<getPfamHub($pfamName)>

Returns Pfam hub data for a given Pfam hub name

=head4 Parameters

=over

=item C<$pfamName>

Pfam hub name that is in the GNN

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

