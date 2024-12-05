
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
    $self->{pfam_writer} = new EFI::GNT::GNN::TableWriter::PfamHubs(colors => $self->{colors});

    return $self;
}


sub savePfamNeighborhoods {
    my $self = shift;
    my $outputDir = shift;

    # Create directories for all of the Pfam neighborhood tables
    $self->{pfam_writer}->initFilteredHubTableDirs($outputDir);
    $self->{pfam_writer}->initAllHubTableDirs($outputDir);

    my @pfamHubNames = $self->{hubs}->getPfamHubNames();

    my $filterOnCooccurrence = 1;
    foreach my $pfamHubName (@pfamHubNames) {
        # All clusters, no cooccurrence filtering
        $self->{pfam_writer}->writeHubTables($pfamHubName, !$filterOnCooccurrence);
        # Filter on cooccurrence
        $self->{pfam_writer}->writeHubTables($pfamHubName, $filterOnCooccurrence);
    }

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

