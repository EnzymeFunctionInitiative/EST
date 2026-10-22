
use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Options;
use EFI::SSN::Util::ID qw(parse_cluster_map_file parse_metanode_map_file parse_singletons_file resolve_mapping);


# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();


my ($clusterToIdMap, $clusterToSeqMap) = parse_cluster_map_file($opts->{cluster_map});

my ($idType, $sourceIdMap) = parse_metanode_map_file($opts->{seqid_source_map});

my $fullClusterToId = resolve_mapping($clusterToIdMap, $idType, $sourceIdMap);

my $singletons = parse_singletons_file($opts->{singletons});

my $c = 0;
my %singletonNumbers = map { $c++; $_ => "S$c" } @$singletons;



open my $fh, ">", $opts->{shortbred_map} or die "Unable to write ShortBRED cluster mapping to '$opts->{shortbred_map}': $!";

foreach my $clusterId (keys %$fullClusterToId) {
    foreach my $id (@{ $fullClusterToId->{$clusterId} }) {
        $fh->print(join("\t", $clusterId, $id), "\n");
    }
}

foreach my $singleton (@$singletons) {
    $fh->print(join("\t", $singletonNumbers{$singleton}, $singleton), "\n");
}

close $fh;















sub validateAndProcessOptions {
    my $optParser = new EFI::Options(app_name => $0, desc => "Creates a file for mapping clusters to sequence IDs, in the format ShortBRED expects");

    $optParser->addOption("cluster-map=s", 1, "path to a file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("seqid-source-map=s", 1, "path to a file mapping repnode or UniRef IDs in the SSN to sequence IDs within the repnode or UniRef ID cluster (optional)", OPT_FILE);
    $optParser->addOption("singletons=s", 1, "path to a file containing a list of singletons", OPT_FILE);
    $optParser->addOption("shortbred-map=s", 1, "path to output file", OPT_FILE);

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    my $opts = $optParser->getOptions();

    return $opts;
}

