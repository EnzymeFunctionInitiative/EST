
package EFI::GNT::GNN::XgmmlWriter::PfamHub;

use strict;
use warnings;

use List::Util qw(sum max);

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../../";

use parent qw(EFI::GNT::GNN::XgmmlWriter);

use EFI::Annotations::Fields qw(FIELD_CYTOSCAPE_COLOR);
use EFI::GNT::GNN::XgmmlWriter::Util;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);
    $self->{gnn_file} = $args{gnn_file} || die "Require GNN file gnn_file output arg";
    $self->{gnt_anno} = $args{gnt_anno} || die "Require EFI::GNT::Annotations gnt_anno arg";
    $self->{util} = new EFI::GNT::GNN::XgmmlWriter::Util(gnt_anno => $args{gnt_anno});

    return $self;
}


sub write {
    my $self = shift;
    my $hubs = shift;

    $self->open() if not $self->{output};

    my @pfamHubNames = $hubs->getPfamHubNames();

    my $filterOnCooccurrence = 1;
    foreach my $pfamHubName (@pfamHubNames) {
        my $hub = $hubs->getPfamHub($pfamHubName, $filterOnCooccurrence);
        my @clusterNums = sort keys %$hub;

        foreach my $clusterNum (@clusterNums) {
            # Skip singletons
            next if not $clusterNum;

            my $spokeNodeId = "$pfamHubName:$clusterNum";
            my $nodeAttr = $self->getSpokeData($pfamHubName, $clusterNum, $hub->{$clusterNum});

            $self->writeNode($spokeNodeId, "$clusterNum", $nodeAttr);
            $self->writeEdge($pfamHubName, $spokeNodeId);
        }

        # Only write a hub node if there were spoke nodes
        if (@clusterNums) {
            my $nodeAttr = $self->getHubData($pfamHubName, $hub);
            my ($familyNames, $pfamShortName, $pfamLongName) = $self->{gnt_anno}->getFamilyNames($pfamHubName);
            $self->writeNode($pfamHubName, "$pfamShortName", $nodeAttr);
        }
    }

    $self->close();
}


#
# getSpokeData - private method
#
# Returns the node attributes for a cluster spoke node.
#
# Parameters:
#    $pfamHubName - Pfam hub name
#    $clusterNum - cluster spoke number
#    $spoke - data for a cluster spoke in the Pfam hub
#
# Returns:
#    array ref of fields, structured according to the format expected by the
#       writeField() method in the EFI::GNT::GNN::XgmmlWriter module
# 
sub getSpokeData {
    my $self = shift;
    my $pfamHubName = shift;
    my $clusterNum = shift;
    my $spoke = shift;

    my $nodeSize = max(1, $spoke->{cooccurrence} * 100);
    my $color = $self->{colors}->getColor($clusterNum);

    my $nbIds = $self->{util}->getNeighborIds($spoke);
    my ($nbAnno, $numPdb, $numSwissProt) = $self->{gnt_anno}->getHubAnnotations($nbIds);
    my $shape = $self->{gnt_anno}->getShape($numPdb, $numSwissProt);

    my ($queryIds, $arrangement, $queryNeighborInfo) = $self->{util}->populateArrangement($spoke, {anno => $nbAnno});

    my @fields;
    push @fields, {name => "Pfam",                                          value => "",                                        type => "string"};
    push @fields, {name => "Pfam Description",                              value => "",                                        type => "string"};
    push @fields, {name => "Cluster Number",                                value => $clusterNum,                               type => "integer"};
    push @fields, {name => "# of Sequences in SSN Cluster",                 value => $spoke->{num_cluster_ids},                 type => "integer"};
    push @fields, {name => "# of Sequences in SSN Cluster with Neighbors",  value => $spoke->{num_ids_with_neighbors},          type => "integer"};
    push @fields, {name => "# of Queries with Pfam Neighbors",              value => $spoke->{num_query_ids_in_pfam},           type => "integer"};
    push @fields, {name => "# of Pfam Neighbors",                           value => $spoke->{num_neighbors},                   type => "integer"};
    push @fields, {name => "Query Accessions",                              value => $queryIds,                                 type => "string"};
    push @fields, {name => "Query-Neighbor Accessions",                     value => $queryNeighborInfo,                        type => "string"};
    push @fields, {name => "Query-Neighbor Arrangement",                    value => $arrangement,                              type => "string"};
    push @fields, {name => "Average Distance",                              value => $spoke->{average_distance},                type => "real"};
    push @fields, {name => "Median Distance",                               value => $spoke->{median_distance},                 type => "real"};
    push @fields, {name => "Co-occurrence",                                 value => $spoke->{cooccurrence},                    type => "real"};
    push @fields, {name => "Co-occurrence Ratio",                           value => $spoke->{cooccurrence_ratio},              type => "string"};
    push @fields, {name => "Hub Average and Median Distances",              value => [],                                        type => "string"};
    push @fields, {name => "Hub Co-occurrence and Ratio",                   value => [],                                        type => "string"};
    push @fields, {name => FIELD_CYTOSCAPE_COLOR,                           value => $color,                                    type => "string"};
    push @fields, {name => "node.shape",                                    value => $shape,                                    type => "string"};
    push @fields, {name => "node.size",                                     value => $nodeSize,                                 type => "string"};

    return \@fields;
}


#
# getHubData - private method
#
# Returns the node attributes for a Pfam hub node.
#
# Parameters:
#    $pfamHubName - Pfam hub name
#    $hub - data for all of the clusters in the Pfam hub
#
# Returns:
#    array ref of fields, structured according to the format expected by the
#       writeField() method in the EFI::GNT::GNN::XgmmlWriter module
# 
sub getHubData {
    my $self = shift;
    my $pfamHubName = shift;
    my $hub = shift;

    my @clusterNums = keys %$hub;
    my ($familyNames, $pfamShort, $pfamLong) = $self->{gnt_anno}->getFamilyNames($pfamHubName);

    my $color = "#EEEEEE";
    my $shape = "hexagon";
    my $nodeSize = "70.0";

    my $numClusterIds = sum( map { $hub->{$_}->{num_cluster_ids} } @clusterNums );
    my $numIdsWithNeighbors = sum( map { $hub->{$_}->{num_ids_with_neighbors} } @clusterNums );
    my $numNeighbors = sum( map { $hub->{$_}->{num_neighbors} } @clusterNums );
    my $numQueryPfam = sum( map { $hub->{$_}->{num_query_ids_in_pfam} } @clusterNums );

    my @queryIds;
    my @arrangement;
    my @queryNeighborInfo;
    my @distances;
    my @coocData;
    foreach my $clusterNum (@clusterNums) {
        my $spoke = $hub->{$clusterNum};

        my $nbIds = $self->{util}->getNeighborIds($spoke);
        my ($nbAnno) = $self->{gnt_anno}->getHubAnnotations($nbIds);
        my ($queryIds, $arrangement, $queryNeighborInfo) = $self->{util}->populateArrangement($spoke, {anno => $nbAnno});
        push @queryIds, @$queryIds;
        push @arrangement, @$arrangement;
        push @queryNeighborInfo, @$queryNeighborInfo;

        push @distances, "$clusterNum:$spoke->{average_distance}:$spoke->{median_distance}";
        push @coocData, "$clusterNum:$spoke->{cooccurrence}:$spoke->{cooccurrence_ratio}";
    }

    my @fields;
    push @fields, {name => "Pfam",                                          value => $pfamHubName,          type => "string"};
    push @fields, {name => "Pfam Description",                              value => $pfamLong,             type => "string"};
    push @fields, {name => "# of Sequences in SSN Cluster",                 value => $numClusterIds,        type => "integer"};
    push @fields, {name => "# of Sequences in SSN Cluster with Neighbors",  value => $numIdsWithNeighbors,  type => "integer"};
    push @fields, {name => "# of Queries with Pfam Neighbors",              value => $numQueryPfam,         type => "integer"};
    push @fields, {name => "# of Pfam Neighbors",                           value => $numNeighbors,         type => "integer"};
    push @fields, {name => "Query-Neighbor Accessions",                     value => \@queryNeighborInfo,   type => "string"};
    push @fields, {name => "Query-Neighbor Arrangement",                    value => \@arrangement,         type => "string"};
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

=head1 EFI::GNT::GNN::XgmmlWriter::PfamHub

=head2 NAME

B<EFI::GNT::GNN::XgmmlWriter::PfamHub> - Perl helper module for writing Pfam hub GNN files

=head2 SYNOPSIS

    my $dbh = EFI::Database->new()->getHandle();
    my $gnn = new EFI::GNT::GNN(...);
    my $hubs = new EFI::GNT::GNN::Hubs(gnn => $gnn);
    my $gntAnno = new EFI::GNT::Annotations(dbh => $dbh);

    my $pfamGnnFile = "pfam_gnn.xgmml";
    my $pfamHubWriter = new EFI::GNT::GNN::XgmmlWriter::PfamHub(gnn_file => $pfamGnnFile, gnt_anno => $gntAnno);
    $pfamHubWriter->write($hubs);


=head2 DESCRIPTION

B<EFI::GNT::GNN::XgmmlWriter::PfamHub> is a Perl helper module for writing
Pfam hub GNN files.  Data is retrieved from a B<EFI::GNT::GNN::Hubs> object
and used to build the network and associated node attributes.
Additional node attributes are retrieved from an EFI database via the
B<EFI::GNT::Annotations> module.


=head2 METHODS

=head3 C<write($hubs)>

Gets data from the B<EFI::GNT::GNN::Hubs> C<$hubs> object and builds
the XGMML file.

=head4 Example Usage

    $pfamHubWriter->write($hubs);

=cut

