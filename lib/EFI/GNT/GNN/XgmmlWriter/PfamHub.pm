
package EFI::GNT::GNN::XgmmlWriter::PfamHub;

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

    my @pfamHubNames = $hubs->getPfamHubNames();

    foreach my $pfamHubName (@pfamHubNames) {
        my $hub = $hubs->getPfamHub($pfamHubName);

        foreach my $clusterNum (@{ $hub->{clusters} }) {
            my $spokeNodeId = "$pfamHubName:$clusterNum";
            my @attr = $self->getSpokeData($pfamHubName, $clusterNum);

            $self->writeNode($spokeNodeId, "$clusterNum", \@attr);
            $self->writeEdge($pfamHubName, $spokeNodeId);
        }

        my @attr = $self->getHubData($pfamHubName);

        #TODO:
        my $pfamShortName = "";
        $self->writeNode($pfamHubName, "$pfamShortName", \@attr);
    }
}


sub getSpokeData {
    my $self = shift;
    my $pfam = shift;
    my $clusterNum = shift;
}


sub getHubData {
    my $self = shift;
    my $pfam = shift;
}


1;

