
use strict;
use warnings;

use Getopt::Long;
use FindBin;
use JSON;

use lib "$FindBin::Bin/../../lib";

use EFI::Annotations;
use EFI::SSN::Util::ID qw(resolve_mapping parse_cluster_map_file parse_metanode_map_file parse_cluster_num_map);
use EFI::Options;




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




my ($clusterToId) = parse_cluster_map_file($opts->{cluster_map});
my ($singletonCluster) = parse_cluster_map_file($opts->{singletons});

# Determine if the IDs provided are UniRef or RepNode and if so get the input file contents
# that maps UniRef ID to UniProt ID.  If the file doesn't exist then this function
# can still be called since it will return the default value for ID type
my ($idType, $sourceIdMap) = parse_metanode_map_file($opts->{seqid_source_map});

# Expand the metanodes
my $expandedClusterToId = resolve_mapping($clusterToId, $idType, $sourceIdMap);

my ($clusterSizesBySeq, $clusterSizesByNode) = parse_cluster_num_map($opts->{cluster_num_map});

my $cdhit = new EFI::CdHit::Parser(file => $opts->{marker_clusters});


my $numSingletons = $singletonCluster->{0} ? @{ $singletonCluster->{0} } : 0;
my $numSequenceIds = countIds($clusterSizesBySeq); # In the SSN, before uniqueing
my $numNodeIds = countIds($clusterSizesByNode); # In the SSN, before uniqueing
my $numMarkers = countFastaHeaders($opts->{markers});
my $numUniqueIds = countLines($opts->{unique_ids});
my $numFilteredSeq = countFastaHeaders($opts->{all_sequences});

my $sbCdhit = $cdhit->getClusterIds();
my $numCdhit = @{ $sbCdhit };

my $md = {};
$md->{num_ssn_clusters} = keys %$clusterToId;                   # Number of SSN clusters
$md->{num_ssn_singletons} = $numSingletons;                     # Number of SSN singletons
$md->{is_uniref} = $idType =~ m/uniref(\d+)/ ? $1 : "";         # SSN Sequence Source
$md->{num_metanodes} = $numNodeIds + $numSingletons;            # Number of SSN (meta)nodes
$md->{num_raw_accession} = $numSequenceIds + $numSingletons;    # Number of accession IDs in SSN (i.e. expanded from metanodes)
$md->{num_filtered_seq} = $numFilteredSeq;                      # Number of sequences in the SSN after length filtering and before removing redundant sequences
$md->{num_unique_seq} = $numUniqueIds;                          # Number of unique sequences in SSN
$md->{num_cdhit_clusters} = $numCdhit;                          # Number of CD-HIT ShortBRED families (i.e. cdhit from sb results)
$md->{num_markers} = $numMarkers;                               # Number of markers
$md->{min_seq_len} = $opts->{min_seq_len};
$md->{max_seq_len} = $opts->{max_seq_len};

my $json = encode_json($md);

open my $fh, ">", $opts->{metadata} or die "Unable to write to metadata file '$opts->{metadata}': $!";
$fh->print($json);
close $fh;










#
# countLines - private method
#
# Count the number of lines in a file.
#
# Parameters:
#    $file - path to a file to count
#
# Returns:
#    number of lines in the file
#
sub countLines {
    my $file = shift;

    my $numLines = countFile($file);

    return $numLines;
}


#
# countFastaHeaders - private method
#
# Count the number of headers in a FASTA file.
#
# Parameters:
#    $file - path to a file to count
#
# Returns:
#    number of headers in the file
#
sub countFastaHeaders {
    my $file = shift;

    my $countFn = sub {
        return ($_ ? $_ =~ m/^>(.+)$/ : 0);
    };

    my $numMarkers = countFile($file, $countFn);

    return $numMarkers;
}


#
# countFile - private method
#
# Arbitrary file counting method.  If a closure is specified then the
# return value of the closure is used to determine if the line is counted.
#
# Parameters:
#    $file - path to a file to count
#    $countFn - optional closure (anonymous function), must return a value
#
# Returns:
#    number of headers in the file
#
sub countFile {
    my $file = shift;
    my $countFn = shift;

    open my $fh, "<", $file or die "Unable to read file '$file': $!";

    my $theCount = 0;
    if (not $countFn) {
        $countFn = sub { $theCount++; };
    }

    while (my $line = <$fh>) {
        chomp $line;
        $countFn->($line);
    }

    close $fh;

    return $theCount;
}
    

#
# countIds - private method
#
# Count the total number of IDs in SSN clusters by using the cluster number
# map file that is output in the colorssn workflow.  Singletons are not used.
#
# Parameters:
#    $clusterSize - hash ref mapping cluster number to cluster size (see
#       parse_cluster_num_map in EFI::SSN::Util::ID for format and usage)
#
# Returns:
#    total number of IDs in the SSN clusters
#       
sub countIds {
    my $clusterSize = shift;
    my $numIds = 0;
    foreach my $clusterNum (keys %$clusterSize) {
        $numIds += $clusterSize->{$clusterNum};
    }
    return $numIds;
}


sub validateAndProcessOptions {

    my $optParser = new EFI::Options(app_name => $0, desc => "Outputs a JSON file that contains metadata from the CGFP computation.");

    $optParser->addOption("all-sequences=s", 1, "path to a FASTA file containing all of the original SSN sequences (minus those optionally filtered for length)", OPT_FILE);
    $optParser->addOption("cluster-map=s", 1, "path to a file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("cluster-num-map=s", 1, "path to a file containing sizes of clusters", OPT_FILE);
    $optParser->addOption("marker-clusters=s", 1, "path to ShortBRED CD-HIT marker clusters", OPT_FILE);
    $optParser->addOption("markers=s", 1, "path to ShortBRED markers file", OPT_FILE);
    $optParser->addOption("min-seq-len=i", 0, "minimum sequence length that was used in filtering upstream (optional)", OPT_VALUE, "none");
    $optParser->addOption("max-seq-len=i", 0, "maximum sequence length that was used in filtering upstream (optional)", OPT_VALUE, "none");
    $optParser->addOption("metadata=s", 1, "path to the output file that will contain the metadata as JSON", OPT_FILE);
    $optParser->addOption("seqid-source-map=s", 1, "path to a file mapping repnode or UniRef IDs in the SSN to sequence IDs within the repnode or UniRef ID cluster", OPT_FILE);
    $optParser->addOption("singletons=s", 0, "path to a file listing the singletons (optional)", OPT_FILE);
    $optParser->addOption("unique-ids=s", 1, "path to a file listing the unique IDs in the input SSN (including singletons)", OPT_FILE);

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


