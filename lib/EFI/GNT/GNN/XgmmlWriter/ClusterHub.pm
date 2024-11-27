
package EFI::GNT::GNN::XgmmlWriter::ClusterHub;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../../";

use parent qw(EFI::GNT::GNN::XgmmlWriter);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);
    $self->{gnn_file} = $args{gnn_file} || die "Require GNN file gnn_file output arg";
    $self->{gnt_anno} = $args{gnt_anno} || die "Require EFI::GNT::Annotations gnt_anno arg";

    return $self;
}


sub write {
    my $self = shift;
    my $hubs = shift;

    my @clusterNums = $hubs->getClusterHubNumbers();

    foreach my $clusterNum (@clusterNums) {
        my $hub = $hubs->getClusterHub($clusterNum);

        foreach my $pfam (@{ $hub->{pfams} }) {
            my $spokeNodeId = "$clusterNum:$pfam";
            my @attr = $self->getSpokeData($clusterNum, $pfam);

            #TODO
            my $pfamShortName = "";
            $self->writeNode($spokeNodeId, "$pfamShortName", \@attr);
            $self->writeEdge($clusterNum, $spokeNodeId);
        }

        my @attr = $self->getHubData($clusterNum);

        $self->writeNode($clusterNum, "$clusterNum", \@attr);
    }
}


sub getSpokeData {
    my $self = shift;
    my $clusterNum = shift;
    my $pfam = shift;
}


sub getHubData {
    my $self = shift;
    my $clusterNum = shift;
}


1;

