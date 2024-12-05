
package EFI::GNT::GNN::TableWriter;

use strict;
use warnings;

use File::Path qw(make_path);

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";

use EFI::Annotations;
use EFI::Util::Colors;

use EFI::GNT::GNN::TableWriter::PfamHubs;


sub new {
    my $class = shift;
    my %args = @_;

    die "Require EFI::GNT::GNN argument" if not $args{gnn};
    die "Require EFI::GNT::GNN::Hubs argument" if not $args{hubs};

    my $self = {};
    bless $self, $class;

    $self->{colors} = $args{colors} // new EFI::Util::Colors();

    $self->{hubs} = $args{hubs};
    #TODO: do something with gnn and hubs

    $self->{efi_anno} = new EFI::Annotations();

    return $self;
}


sub savePfamNeighborhoods {
    my $self = shift;
    my $outputDir = shift;

    my $writer = new EFI::GNT::GNN::TableWriter::PfamHubs(hubs => $self->{hubs}, colors => $self->{colors}, output_dir => $outputDir);

    my $filterOnCooccurrence = 1;

    my @pfamHubNames = $self->{hubs}->getPfamHubNames();
    foreach my $pfamHubName (@pfamHubNames) {
        my $hub = $self->{hubs}->getPfamHub($pfamHubName, !$filterOnCooccurrence);
        # All clusters, no cooccurrence filtering
        $writer->writeAllHubTables($pfamHubName, $hub);

        # Filter on cooccurrence
        $hub = $self->{hubs}->getPfamHub($pfamHubName, $filterOnCooccurrence);
        $writer->writeFilteredHubTables($pfamHubName, $hub);
    }

    $writer->finish();
}
















sub saveUnclassifiedIds {
    my $self = shift;
    my $unclassifiedIdsDir = shift;
}


sub saveStatistics {
    my $self = shift;
    my $statsFile = shift;
}


sub saveConvergenceRatio {
    my $self = shift;
    my $convRatioFile = shift;
}


sub savePfamCoocurrence {
    my $self = shift;
    my $pfamCoocFile = shift;
}




1;
__END__

