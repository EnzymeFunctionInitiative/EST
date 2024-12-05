
package EFI::GNT::GNN::TableWriter::PfamHubs;

use strict;
use warnings;

use constant PFAM_HUB_COOC => 1;
use constant PFAM_HUB_ALL => 2;
use constant PFAM_SPLIT => 4;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless $self, $class;

    $self->{colors} = $args{colors};
    $self->{hubs} = $args{hubs};

    $self->{pfam_dirs} = {&PFAM_HUB_COOC => "", &PFAM_HUB_COOC|&PFAM_SPLIT => "", &PFAM_HUB_ALL => "", &PFAM_HUB_ALL|&PFAM_SPLIT => ""};
}


sub writeHubTables {
    my $self = shift;
    my $pfamHubName = shift;
    my $filterOnCooccurrence = shift;

    my $hub = $self->{hubs}->getPfamHub($pfamHubName, $filterOnCooccurrence);

    my @clusterNums = sort keys %$hub;

    foreach my $clusterNum (@clusterNums) {
        my $cluster = $hub->{$clusterNum};
        my $color = $self->{colors}->getColor($clusterNum);

        #TODO: open the file
        #my $outFile = $dirPath . "/pfam_neighbors_$pfam.txt";
        #my $fileExists = -f $outFile;
        #my $mode = $dataType & PFAM_SPLIT ? ">>" : ">";
        #open my $fh, $mode, $outFile or die "Unable to write to PFAM $outFile: $!";
        #if (not $fileExists) {
        #    $fh->print(join("\t", $self->getPfamHubTableHeaders()), "\n");
        #}

        foreach my $queryId (keys %$cluster) {
            foreach my $nb (@{ $cluster->{$queryId}->{query_neighbors} }) {
                my @line = ($queryId, $nb->{id}, $pfamHubName, $color, $nb->{distance}, $nb->{direction});
                my $line = join("\t", @line);
                #TODO: output the line
                #$fh->print($line, "\n");
            }
        }

        #TODO: close file handle
        #$fh->close();
    }

    #TODO: split up pfam and write to split dir
}



#
# initPfamNeighborhoodDir - private method
#
# Initializes a Pfam hub output directory, as well as the master file containing
# all of the IDs, not just the ones in the hubs
#
# Parameters:
#    $dataType - one of PFAM_HUB_COOC or PFAM_HUB_ALL, can be combined with PFAM_SPLIT
#
sub initPfamNeighborhoodDir {
    my $self = shift;
    my $dataType = shift;

    my $outputDir = $self->{pfam_dirs}->{$dataType};

    if (not -d $outputDir) {
        make_path($outputDir) or die "Unable to create directory $outputDir: $!";
    }

    my $allPath = "$outputDir/ALL_PFAM.txt";
    open my $allFh, ">", $allPath or die "Unable to write to $allPath: $!";
    $self->{pfam_hub_files}->{$dataType}->{_ALL} = $allFh;

    my @headers = $self->getPfamHubTableHeaders();

    $allFh->print(join("\t", @headers), "\n");
}


# for unfiltered
sub initAllHubTableDirs {
    my $self = shift;
    my $outputDir = shift;

    # All Pfam hubs, even those that are less than the cooccurrence threshold
    $self->{pfam_dirs}->{&PFAM_HUB_ALL} = "$outputDir/all_pfam";
    # Each Pfam ID from the hub (e.g. hub is split), even those that are less than the cooccurrence threshold
    $self->{pfam_dirs}->{&PFAM_HUB_ALL | &PFAM_SPLIT} = "$outputDir/split_all_pfam";

    # Initialize directory for all the query IDs in all of the Pfam hubs, grouped by hub name
    # (e.g. multiple family IDs joined by hyphen).  All hubs are considered, i.e. no
    # filtering by cooccurrence is performed.
    $self->initPfamNeighborhoodDir(PFAM_HUB_ALL);
    # Initialize directory for all the query IDs in all of the Pfams, but each Pfam has it's
    # own file (e.g. the hub name has been split into the constituent family IDs).
    # All hubs are considered, i.e. no filtering by cooccurrence is performed.
    $self->initPfamNeighborhoodDir(PFAM_HUB_ALL | PFAM_SPLIT);
}


sub initFilteredHubTableDirs {
    my $self = shift;
    my $outputDir = shift;

    # Pfam hub name, meeting cooccurrence threshold
    $self->{pfam_dirs}->{&PFAM_HUB_COOC} = "$outputDir/pfam";
    # Each Pfam ID from the hub (e.g. hub is split), meeting cooccurrence threshold
    $self->{pfam_dirs}->{&PFAM_HUB_COOC | &PFAM_SPLIT} = "$outputDir/split_pfam";

    # Initialize directory for all the query IDs in all of the Pfam hubs, grouped by hub name
    # (e.g. multiple family IDs joined by hyphen).  The hubs are filtered by cooccurrence.
    $self->initPfamNeighborhoodDir(PFAM_HUB_COOC);
    # Initialize directory for all the query IDs in all of the Pfams, but each Pfam has it's
    # own file (e.g. the hub name has been split into the constituent family IDs).
    # The hubs are filtered by cooccurrence.
    $self->initPfamNeighborhoodDir(PFAM_HUB_COOC | PFAM_SPLIT);
}


# private
sub getPfamHubTableHeaders {
    my $self = shift;
    my @headers = ("Query ID", "Neighbor ID", "Neighbor Pfam", "SSN Query Cluster #", "SSN Query Cluster Color", "Query-Neighbor Distance", "Query-Neighbor Directions");
    return @headers;
}


1;
__END__

