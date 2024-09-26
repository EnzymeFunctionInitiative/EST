
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::SSN::Util::ID qw(resolve_mapping parse_cluster_map_file parse_metanode_map_file);
use EFI::Options;




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




# Get the map of cluster number to list of IDs
my $clusterToId = parse_cluster_map_file($opts->{cluster_map});

# Get the metanode data (mapping of repnode/UniRef to UniProt)
my ($idType, $sourceIdMap) = parse_metanode_map_file($opts->{seqid_source_map});

my $fullClusterToId = resolve_mapping($clusterToId, $idType, $sourceIdMap);

my $singletons = loadSingletons($opts->{singletons});

my $stats = computeStats($opts->{stats}, $clusterToId, $fullClusterToId, $idType, $singletons);


















#
# computeStats
#
# Compute and/or save the size of clusters, number of singletons, etc.
#
# Parameters:
#    $statsFile - path to output file
#    $clusterToId - mapping of cluster number to metanode IDs
#    $fullClusterToId - mapping of cluster number to sequence IDs (metanodes expanded)
#    $idType - type of metanode (e.g. UniRef/RepNode)
#    $singletons - array ref of singletons in the SSN
#
sub computeStats {
    my $statsFile = shift;
    my $clusterToId = shift;
    my $fullClusterToId = shift;
    my $idType = shift;
    my $singletons = shift;

    my $numNodes = 0;
    my $numSequences = 0;

    my @clusters = sort { $a <=> $b } keys %$clusterToId;
    foreach my $cnum (@clusters) {
        $numNodes += @{ $clusterToId->{$cnum} };
        $numSequences += @{ $fullClusterToId->{$cnum} };
    }

    my $numClusters = @clusters;
    my $numSingletons = @$singletons;

    if ($idType =~ m/uniref(\d+)/i) {
        $idType = "UniRef$1";
    } else {
        $idType = "UniProt";
    }

    open my $fh, ">", $statsFile or die "Unable to write to stats file '$statsFile': $!";
    $fh->print(join("\t", "Number of SSN clusters", $numClusters), "\n");
    $fh->print(join("\t", "Number of SSN singletons", $numSingletons), "\n");
    $fh->print(join("\t", "SSN sequence source", $idType), "\n");
    $fh->print(join("\t", "Number of SSN (meta)nodes", $numNodes), "\n");
    $fh->print(join("\t", "Number of accession IDs in SSN", $numSequences), "\n");
    close $fh;
}


#
# loadSingletons
#
# Load the singletons in the SSN; the file includes a header line
#
# Parameters:
#    $file - single column file to parse
#
sub loadSingletons {
    my $file = shift;

    open my $fh, "<", $file or die "Unable to open singletons file '$file' for reading: $!";

    my @ids;

    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        push @ids, $_;
    }

    close $fh;

    return \@ids;
}


sub validateAndProcessOptions {

    my $optParser = new EFI::Options(app_name => $0, desc => "Outputs a file listing the convergence ratio for each cluster in the input cluster map");

    $optParser->addOption("cluster-map=s", 1, "path to a file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("seqid-source-map=s", 1, "path to a file mapping repnode or UniRef IDs in the SSN to sequence IDs within the repnode or UniRef ID cluster (optional)", OPT_FILE);
    $optParser->addOption("singletons=s", 1, "path to a file containing a list of singletons", OPT_FILE);
    $optParser->addOption("stats=s", 1, "path to an output file to save statistics to", OPT_FILE);

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


