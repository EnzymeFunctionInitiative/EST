
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Options;
use EFI::SSN::XgmmlWriter::Color;
use EFI::SSN::Util::Colors;




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




my $colors = getColors($opts->{color_file});
my $clusterSizes = parseClusterSizeFile($opts->{cluster_size});
my $clusterMap = parseClusterFile($opts->{cluster_map});

my $xwriter = EFI::SSN::XgmmlWriter::Color->new(ssn => $opts->{ssn}, color_ssn => $opts->{color_ssn}, cluster_map => $clusterMap, cluster_sizes => $clusterSizes, colors => $colors);

$xwriter->write();

if ($opts->{cluster_color_map}) {
    saveClusterColorMap($opts->{cluster_color_map}, $xwriter->getClusterColors());
}


















#
# saveClusterColorMap
#
# Save the mapping of cluster number to cluster color to a file
#
# Parameters:
#    $mapFile - path to file to save mapping to
#    $clusterColors - hash ref of cluster number (in the SSN) -> hex color
#
sub saveClusterColorMap {
    my $mapFile = shift;
    my $clusterColors = shift;

    open my $fh, ">", $mapFile or die "Unable to write to cluster color map file '$mapFile': $!";

    $fh->print(join("\t", "cluster_num_seq", "color"), "\n");

    my @clusters = sort { $a <=> $b } keys %$clusterColors;
    foreach my $cnum (@clusters) {
        $fh->print(join("\t", $cnum, $clusterColors->{$cnum}), "\n");
    }

    $fh->close();
}


#
# parseClusterSizeFile
#
# Parse the cluster size file that is created by the pipeline upstream.
# File format is cluster number by sequence, cluster size by sequence,
# cluster number by node, cluster size by node
#
# Parameters:
#    $mapFile - path to file containing mapping
#
# Returns:
#    hash ref with two elements:
#       seq => hash ref of sequence cluster number -> size
#       node => hash ref of node cluster number -> size
#
sub parseClusterSizeFile {
    my $mapFile = shift;

    open my $fh, "<", $mapFile or die "Unable to read cluster map file '$mapFile': $!";

    my $headerLine = <$fh>;

    my $seqSizes = {};
    my $nodeSizes = {};

    while (my $line = <$fh>) {
        chomp $line;
        my ($seqNum, $seqSize, $nodeNum, $nodeSize) = split(m/\t/, $line);
        $seqSizes->{$seqNum} = $seqSize;
        $nodeSizes->{$nodeNum} = $nodeSize;
    }

    close $fh;

    return {seq => $seqSizes, node => $nodeSizes};
}


#
# parseClusterFile - internal method
#
# Parse the cluster info file provided to the script to obtain a mapping of sequence ID
# to cluster number and size
#
# Parameters:
#    $clusterFile - path to file to load
#       contains three columns, sequence ID, cluster number by sequence, cluster number by node
#
# Returns:
#    hash ref mapping sequence ID to two element array ref;
#    first element is sequence cluster number, second is node cluster number
#
sub parseClusterFile {
    my $clusterFile = shift;

    my $clusterMap = {};
    
    open my $fh, "<", $clusterFile or die "Unable to read cluster file '$clusterFile': $!";

    my $header = <$fh>;
    return if not $header;
    my ($seqNumCol, $nodeNumCol) = get_cluster_num_cols($header);

    while (my $line = <$fh>) {
        chomp $line;
        my ($seqId, @p) = split(m/\t/, $line);
        my $seqNum = $p[$seqNumCol];
        my $nodeNum = $p[$nodeNumCol];
        $clusterMap->{$seqId} = [$seqNum, $nodeNum];
    }

    close $fh;

    return $clusterMap;
}


#
# getColors
#
# Returns an object that can be used to color clusters
#
sub getColors {
    my $colorFile = shift;
    return new EFI::SSN::Util::Colors(color_file => $colorFile);
}


sub validateAndProcessOptions {

    my $desc = "Parses a SSN XGMML file and writes it to a new SSN file after coloring and numbering the nodes based on cluster. This is done without creating a DOM since elements are written one by one to the file as they are built.";

    my $optParser = new EFI::Options(app_name => $0, desc => $desc);

    $optParser->addOption("ssn=s", 1, "path to input XGMML (XML) SSN file", OPT_FILE);
    $optParser->addOption("color-ssn=s", 1, "path to output colored SSN (XGMML) file", OPT_FILE);
    $optParser->addOption("cluster-map=s", 1, "path to output file mapping node index (col 1) to cluster numbers (num by seq, num by nodes)", OPT_FILE);
    $optParser->addOption("cluster-size=s", 1, "path to input file containing the cluster sizes", OPT_FILE);
    $optParser->addOption("cluster-color-map=s", 0, "path to output file mapping cluster number (sequence count) to a color", OPT_FILE);
    $optParser->addOption("color-file=s", 0, "path to a file containing a list of colors by cluster; if not specified defaults to 'colors.tab' in the script directory", OPT_FILE);

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


