
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../lib";

use EFI::CdHit::Parser;
use EFI::Options;
use EFI::SSN::Util::ID qw(parse_cluster_map_file);
use EFI::Util::Colors;




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




my ($clusterToId) = parse_cluster_map_file($opts->{cluster_map});
my $idToCluster = reverseMap($clusterToId);

my $cdhitParser = new EFI::CdHit::Parser(file => $opts->{marker_clusters});

my %colorParams;
$colorParams{color_file} = $opts->{colors} if ($opts->{colors} and -f $opts->{colors});
my $colors = new EFI::Util::Colors(%colorParams);

outputTable($idToCluster, $cdhitParser, $colors, $opts->{table});























sub reverseMap {
    my $clusterToId = shift;

    my $idMap = {};
    foreach my $cluster (keys %$clusterToId) {
        map { $idMap->{$_} = $cluster; } @{ $clusterToId->{$cluster} };
    }

    return $idMap;
}


sub outputTable {
    my $idToCluster = shift;
    my $cdhitParser = shift;
    my $colors = shift;
    my $tableFile = shift;

    my @headers = ("Cluster Number", "CD-HIT Seed Sequence", "Protein");
    push @headers, "CD-HIT Seed Sequence Color (If has a Marker)";

    open my $fh, ">", $tableFile or die "Unable to write to table file '$tableFile': $!";

    $fh->print(join("\t", @headers), "\n");

    my $clusters = $cdhitParser->getClusterIds();
    foreach my $cluster (@$clusters) {
        my $ids = $cdhitParser->getMembers($cluster);
        foreach my $id (@$ids) {
            my $clusterNum = $idToCluster->{$id} // "N/A";
            my @vals = ($clusterNum, $cluster, $id);
            push @vals, $colors->getColor($clusterNum);
            $fh->print(join("\t", @vals), "\n");
        }
    }

    $fh->close();
}


sub validateAndProcessOptions {

    # Text wrapping occurs in the EFI::Options help output.
    my $desc = "Outputs a table mapping unique sequences to colors based on cluster number.";
    my $fileFormatDesc =
        "The output table is a tab separated file with headers, with columns 'Cluster Number', " .
        "'CD-HIT Seed Sequence', and 'Protein'.  If a protein has a marker, then an additional " .
        "column, 'CD-HIT Seed Sequence Color (If has a Marker)', is output.";
    my $optParser = new EFI::Options(app_name => $0, desc => $desc, ext_desc => $fileFormatDesc);

    $optParser->addOption("cluster-map=s", 1, "path to a file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("marker-clusters=s", 1, "path to ShortBRED CD-HIT marker clusters", OPT_FILE);
    $optParser->addOption("table=s", 1, "path to an output file containing the mapping cluster to marker clusters", OPT_FILE);
    $optParser->addOption("colors=s", 0, "path to a file containing a mapping of clusters to color (optional, defaults to values provided by EFI::Util::Colors)", OPT_FILE);

    if (not $optParser->parseOptions()) {
        my $text = $optParser->printHelp(OPT_ERRORS);
        die "$text\n";
        exit(1);
    }

    if ($optParser->wantHelp()) {
        my $text = $optParser->printHelp();
        print $text;
        exit(0);
    }

    return $optParser->getOptions();
}


