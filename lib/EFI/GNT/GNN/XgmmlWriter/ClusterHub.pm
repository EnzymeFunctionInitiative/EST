
package EFI::GNT::GNN::XgmmlWriter::ClusterHub;

use strict;
use warnings;

use List::Util qw(sum max);

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../../";

use parent qw(EFI::GNT::GNN::XgmmlWriter);

use EFI::Annotations::Fields qw(FIELD_CYTOSCAPE_COLOR);
use EFI::GNT::GNN::XgmmlWriter::Util;
use EFI::GNT::GNN::Hubs qw(NONE_PFAM FILTER_COOCCURRENCE DEFAULT_COOCCURRENCE_THRESHOLD);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);
    $self->{gnn_file} = $args{gnn_file} || die "Require GNN file gnn_file output arg";
    $self->{gnt_anno} = $args{gnt_anno} || die "Require EFI::GNT::Annotations gnt_anno arg";
    $self->{util} = new EFI::GNT::GNN::XgmmlWriter::Util(gnt_anno => $args{gnt_anno});
    #$self->{colors} is created by the parent class
    $self->{cooc_threshold} = DEFAULT_COOCCURRENCE_THRESHOLD;

    return $self;
}


sub write {
    my $self = shift;
    my $hubs = shift;

    $self->open() if not $self->{output};

    my @clusterNums = $hubs->getClusterHubNumbers();

    foreach my $clusterNum (@clusterNums) {
        # Skip singletons
        next if not $clusterNum;

        my $hub = $hubs->getClusterHub($clusterNum, FILTER_COOCCURRENCE);
        # Skip clusters that only have one sequence with genome context
        next if $hub->{num_ids_with_neighbors} < 2;

        my @pfamHubNames = keys %{ $hub->{spokes} };

        foreach my $pfamHubName (@pfamHubNames) {
            my $spokeNodeId = "$clusterNum:$pfamHubName";
            my ($familyNames, $pfamShortName, $pfamLongName) = $self->{gnt_anno}->getFamilyNames($pfamHubName);

            my $nodeAttr = $self->getSpokeData($clusterNum, $pfamHubName, $hub->{spokes}->{$pfamHubName}, $pfamLongName);

            $self->writeNode($spokeNodeId, "$pfamShortName", $nodeAttr);
            $self->writeEdge($clusterNum, $spokeNodeId);
        }

        # Only write a hub node if there were spoke nodes
        if (@pfamHubNames) {
            my $nodeAttr = $self->getHubData($clusterNum, $hub);
            $self->writeNode($clusterNum, "$clusterNum", $nodeAttr);
        }
    }

    $self->close();
}


#
# getSpokeData - private method
#
# Returns the node attributes for a Pfam spoke node.
#
# Parameters:
#    $clusterNum - cluster hub number
#    $pfam - Pfam spoke name
#    $spoke - data for a Pfam spoke in the cluster hub
#    $pfamLongName - long name for the Pfam
#
# Returns:
#    array ref of fields, structured according to the format expected by the
#       writeField() method in the EFI::GNT::GNN::XgmmlWriter module
# 
sub getSpokeData {
    my $self = shift;
    my $clusterNum = shift;
    my $pfam = shift;
    my $spoke = shift;
    my $pfamLongName = shift;

    my $nodeSize = max(1, int($spoke->{num_query_ids_in_pfam} / $spoke->{num_ids_with_neighbors} * 100));
    my $color = "#EEEEEE";

    my $nbIds = $self->{util}->getNeighborIds($spoke);
    my ($nbAnno, $numPdb, $numSwissProt) = $self->{gnt_anno}->getHubAnnotations($nbIds);
    my $shape = $self->{gnt_anno}->getShape($numPdb, $numSwissProt);

    my ($queryIds, $arrangement, $queryNeighborInfo) = $self->{util}->populateArrangement($spoke, {pfam => $pfam, anno => $nbAnno});

    my @fields;
    push @fields, {name => "SSN Cluster Number",                            value => $clusterNum,                               type => "integer"};
    push @fields, {name => "Pfam",                                          value => $pfam,                                     type => "string"};
    push @fields, {name => "Pfam Description",                              value => $pfamLongName,                             type => "string"};
    push @fields, {name => "# of Queries with Pfam Neighbors",              value => $spoke->{num_query_ids_in_pfam},           type => "integer"};
    push @fields, {name => "# of Pfam Neighbors",                           value => $spoke->{num_neighbors},                   type => "integer"};
    push @fields, {name => "# of Sequences in SSN Cluster",                 value => $spoke->{num_cluster_ids},                 type => "integer"};
    push @fields, {name => "# of Sequences in SSN Cluster with Neighbors",  value => $spoke->{num_ids_with_neighbors},          type => "integer"};
    push @fields, {name => "Query Accessions",                              value => $queryIds,                                 type => "string"};
    push @fields, {name => "Query-Neighbor Accessions",                     value => $queryNeighborInfo,                        type => "string"};
    push @fields, {name => "Query-Neighbor Arrangement",                    value => $arrangement,                              type => "string"};
    push @fields, {name => "Average Distance",                              value => $spoke->{average_distance},                type => "real"};
    push @fields, {name => "Median Distance",                               value => $spoke->{median_distance},                 type => "real"};
    push @fields, {name => "Co-occurrence",                                 value => $spoke->{cooccurrence},                    type => "real"};
    push @fields, {name => "Co-occurrence Ratio",                           value => $spoke->{cooccurrence_ratio},              type => "string"};
    push @fields, {name => "Hub Queries with Pfam Neighbors",               value => [],                                        type => "string"};
    push @fields, {name => "Hub Pfam Neighbors",                            value => [],                                        type => "string"};
    push @fields, {name => "Hub Average and Median Distance",               value => [],                                        type => "string"};
    push @fields, {name => "Hub Co-occurrence and Ratio",                   value => [],                                        type => "string"};
    push @fields, {name => FIELD_CYTOSCAPE_COLOR,                           value => $color,                                    type => "string"};
    push @fields, {name => "node.shape",                                    value => $shape,                                    type => "string"};
    push @fields, {name => "node.size",                                     value => $nodeSize,                                 type => "string"};

    return \@fields;
}


#
# getHubData - private method
#
# Returns the node attributes for a cluster hub node.
#
# Parameters:
#    $clusterNum - cluster hub number
#    $hub - data for all of the pfam spokes in the given cluster hub
#
# Returns:
#    array ref of fields, structured according to the format expected by the
#       writeField() method in the EFI::GNT::GNN::XgmmlWriter module
# 
sub getHubData {
    my $self = shift;
    my $clusterNum = shift;
    my $hub = shift;

    my $color = $self->{colors}->getColor($clusterNum);
    my $shape = "hexagon";
    my $nodeSize = "70.0";

    my @pfams = sort keys %{ $hub->{spokes} };

    my $numClusterIds = $hub->{num_cluster_ids};
    my $numIdsWithNeighbors = $hub->{num_ids_with_neighbors};

    my @queryNeighbors;
    my @pfamNeighbors;
    my @distances;
    my @coocData;
    foreach my $pfam (@pfams) {
        my $spoke = $hub->{spokes}->{$pfam};
        push @queryNeighbors, "$clusterNum:$pfam:$spoke->{num_query_ids_in_pfam}";
        push @pfamNeighbors, "$clusterNum:$pfam:$spoke->{num_neighbors}";
        push @distances, "$clusterNum:$pfam:$spoke->{average_distance}:$spoke->{median_distance}";
        push @coocData, "$clusterNum:$pfam:$spoke->{cooccurrence}:$spoke->{cooccurrence_ratio}";
    }

    my @fields;
    push @fields, {name => "SSN Cluster Number",                            value => $clusterNum,           type => "integer"};
    push @fields, {name => "# of Sequences in SSN Cluster",                 value => $numClusterIds,        type => "integer"};
    push @fields, {name => "# of Sequences in SSN Cluster with Neighbors",  value => $numIdsWithNeighbors,  type => "integer"};
    push @fields, {name => "Hub Queries with Pfam Neighbors",               value => \@queryNeighbors,      type => "string"};
    push @fields, {name => "Hub Pfam Neighbors",                            value => \@pfamNeighbors,       type => "string"};
    push @fields, {name => "Hub Average and Median Distances",              value => \@distances,           type => "string"};
    push @fields, {name => "Hub Co-occurrence and Ratio",                   value => \@coocData,            type => "string"};
    push @fields, {name => FIELD_CYTOSCAPE_COLOR,                           value => $color,                type => "string"};
    push @fields, {name => "node.shape",                                    value => $shape,                type => "string"};
    push @fields, {name => "node.size",                                     value => $nodeSize,             type => "string"};

    return \@fields;
}


1;
__END__

=pod

=head1 EFI::GNT::GNN::XgmmlWriter::ClusterHub

=head2 NAME

B<EFI::GNT::GNN::XgmmlWriter::ClusterHub> - Perl helper module for writing cluster hub GNN files

=head2 SYNOPSIS

    my $dbh = EFI::Database->new()->getHandle();
    my $gnn = new EFI::GNT::GNN(...);
    my $hubs = new EFI::GNT::GNN::Hubs(gnn => $gnn);
    my $gntAnno = new EFI::GNT::Annotations(dbh => $dbh);

    my $clusterGnnFile = "cluster_gnn.xgmml";
    my $clusterHubWriter = new EFI::GNT::GNN::XgmmlWriter::ClusterHub(gnn_file => $clusterGnnFile, gnt_anno => $gntAnno);
    $clusterHubWriter->write($hubs);


=head2 DESCRIPTION

B<EFI::GNT::GNN::XgmmlWriter::ClusterHub> is a Perl helper module for writing
cluster hub GNN files.  Data is retrieved from a B<EFI::GNT::GNN::Hubs> object
and used to build the network and associated node attributes.
Additional node attributes are retrieved from an EFI database via the
B<EFI::GNT::Annotations> module.


=head2 METHODS

=head3 C<write($hubs)>

Gets data from the B<EFI::GNT::GNN::Hubs> C<$hubs> object and builds
the XGMML file.

=head4 Example Usage

    $clusterHubWriter->write($hubs);

=cut

