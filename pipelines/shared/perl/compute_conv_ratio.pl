
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

# Get the edgelist
my $edgelist = parseEdgelist($opts->{edgelist});

# Get the mapping of node index to node sequence ID
my $indexMap = parseIndexSeqidMap($opts->{index_seqid_map});

# Compute degrees, metanode only
my $degrees = computeDegrees($edgelist, $indexMap);

# Expand the metanodes
my $fullClusterToId = resolve_mapping($clusterToId, $idType, $sourceIdMap);

my $convRatios = computeConvRatio($clusterToId, $fullClusterToId, $degrees);

saveConvRatioData($opts->{conv_ratio}, $convRatios);














#
# saveConvRatioData
#
# Save the convergence ratio data to a file
#
# Parameters:
#    $file - path to the output file
#    $data - array ref of data to save
#
sub saveConvRatioData {
    my $file = shift;
    my $data = shift;

    open my $fh, ">", $file or die "Unable to write to convergence ratio file '$file': $!";

    $fh->print(join("\t", "Cluster Number", "Convergence Ratio", "Number of SSN Nodes", "Number of UniProt IDs", "Number of Edges"), "\n");

    foreach my $row (@$data) {
        $fh->print(join("\t", @$row), "\n");
    }

    close $fh;
}


#
# computeConvRatio
#
# Compute the cluster-based convergence ratio
#
# Parameters:
#    $clusterToId - mapping of cluster to SSN nodes (e.g. metanodes/IDs)
#    $fullClusterToId - mapping of cluster to sequences (expanded from metanodes, if relevant)
#    $degrees - node degree hash ref
#
# Returns:
#    array ref of data rows
#
sub computeConvRatio {
    my $clusterToId = shift;
    my $fullClusterToId = shift;
    my $degrees = shift;

    # cluster to conv ratio
    my @data;

    my @clusters = sort { $a <=> $b } keys %$clusterToId;
    foreach my $cnum (@clusters) {
        my @fullIds = @{ $fullClusterToId->{$cnum} };
        my $numNodes = @{ $clusterToId->{$cnum} };
        my $numIds = @fullIds;

        my $numDegree = 0;
        foreach my $id (@fullIds) {
            next if not $degrees->{$id};
            $numDegree += $degrees->{$id};
        }

        my $denom = $numIds * ($numIds - 1);
        my $convRatio = 0;
        $convRatio = $numDegree / $denom if $denom > 0;
        $convRatio = sprintf("%.1e", $convRatio);
        push @data, [$cnum, $convRatio, $numNodes, $numIds, $numDegree / 2];
    }

    return \@data;
}


#
# computeDegrees
#
# Compute the node degrees (the degree of connectivity of each node)
#
# Parameters:
#    $edgelist - the edgelist that comes from parseEdgelist
#    $indexMap - the mapping that comes from parseIndexSeqidMap
#
# Returns:
#    hash ref of sequence ID to degree
#
sub computeDegrees {
    my $edgelist = shift;
    my $indexMap = shift;

    my %nd;
    foreach my $edge (@$edgelist) {
        $nd{$edge->[0]}++;
        $nd{$edge->[1]}++;
    }

    my %degrees;
    foreach my $idx (keys %nd) {
        $degrees{$indexMap->{$idx}} = $nd{$idx};
    }

    return \%degrees;
}


#
# parseIndexSeqidMap
#
# Parse the file that maps node indices to sequence IDs (e.g. UniProt ID)
#
# Parameters:
#    $file - path to map file
#
# Returns:
#    hash ref mapping node index to sequence ID
#
sub parseIndexSeqidMap {
    my $file = shift;

    open my $fh, "<", $file or die "Unable to read index-seqid-map file '$file': $!";

    my $header = <$fh>; # "node_index", "node_seqid", "node_size"

    my $data = {};

    while (my $line = <$fh>) {
        chomp $line;
        next if not $line;
        my ($nodeIdx, $seqId, $nodeSize) = split(m/\t/, $line);
        $data->{$nodeIdx} = $seqId;
    }

    close $fh;

    return $data;
}


#
# parseEdgeList
#
# Read the edgelist file, where each line is an edge with the start and node indices
# being the columns
#
# Parameters:
#    $file - path to edgelist file
#
# Returns:
#    array ref of edgelists, with each element being an array ref of start-end pairs
#
sub parseEdgelist {
    my $file = shift;

    open my $fh, "<", $file or die "Unable to open edgelist file '$file' for reading: $!";

    my @edgelist;

    while (my $line = <$fh>) {
        chomp $line;
        next if not $line;
        my ($n1, $n2) = split(m/[\t ]/, $line);
        push @edgelist, [$n1, $n2];
    }

    close $fh;

    return \@edgelist;
}


sub validateAndProcessOptions {

    my $optParser = new EFI::Options(app_name => $0, desc => "Outputs a file listing the convergence ratio for each cluster in the input cluster map");

    $optParser->addOption("cluster-map=s", 1, "path to a file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("index-seqid-map=s", 1, "path to a file mapping the node index (edgelist ID) to sequence ID", OPT_FILE);
    $optParser->addOption("edgelist=s", 1, "path to a file with the edgelist", OPT_FILE);
    $optParser->addOption("conv-ratio=s", 1, "path to an output file to save convergence ratios", OPT_FILE);
    $optParser->addOption("seqid-source-map=s", 0, "path to a file mapping repnode or UniRef IDs in the SSN to sequence IDs within the repnode or UniRef ID cluster (optional)", OPT_FILE);

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


