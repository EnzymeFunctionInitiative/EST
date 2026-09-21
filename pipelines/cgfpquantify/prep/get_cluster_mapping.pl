
use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Options;
use EFI::SSN::Util::ID qw(parse_cluster_map_file);


# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();


my (undef, $clusterToSeqMap) = parse_cluster_map_file($opts->{cluster_map});




open my $fh, ">", $opts->{shortbred_map} or die "Unable to write ShortBRED cluster mapping to '$opts->{shortbred_map}': $!";

foreach my $clusterId (keys %$clusterToSeqMap) {
    foreach my $id (@{ $clusterToSeqMap->{$clusterId} }) {
        $fh->print(join("\t", $clusterId, $id), "\n");
    }
}

close $fh;















sub validateAndProcessOptions {
    my $optParser = new EFI::Options(app_name => $0, desc => "Creates a file for mapping clusters to sequence IDs, in the format ShortBRED expects");

    $optParser->addOption("cluster-map=s", 1, "path to a file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("shortbred-map=s", 1, "path to output file", OPT_FILE);

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    my $opts = $optParser->getOptions();

    return $opts;
}

