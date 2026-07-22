
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Options;
use EFI::SSN::Util::ID qw(resolve_mapping parse_cluster_map_file parse_metanode_map_file parse_singletons_file);




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




# Get the map of cluster number to list of IDs
my ($clusterToId) = parse_cluster_map_file($opts->{cluster_map});

# Get the metanode data (mapping of repnode/UniRef to UniProt)
my ($idType, $sourceIdMap) = parse_metanode_map_file($opts->{seqid_source_map});

my $fullClusterToId = resolve_mapping($clusterToId, $idType, $sourceIdMap);

my $singletons = parse_singletons_file($opts->{singletons});




open my $fh, ">", $opts->{id_list} or die "Unable to write to ID list file '$opts->{id_list}': $!";
$fh->print("$_\n") for (sort (keys %$fullClusterToId, @$singletons));
close $fh;

















sub validateAndProcessOptions {

    my $optParser = new EFI::Options(app_name => $0, desc => "Outputs a file with all of the IDs, not just metanode IDs");

    $optParser->addOption("cluster-map=s", 1, "path to a file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("seqid-source-map=s", 1, "path to a file mapping repnode or UniRef IDs in the SSN to sequence IDs within the repnode or UniRef ID cluster (optional)", OPT_FILE);
    $optParser->addOption("singletons=s", 1, "path to a file containing a list of singletons", OPT_FILE);
    $optParser->addOption("id-list=s", 1, "path to an output file containing the list of IDs", OPT_FILE);

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    return $optParser->getOptions();
}

