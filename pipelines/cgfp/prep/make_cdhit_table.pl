
use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Options;
use EFI::SSN::Util::ID qw(invert_cluster_map parse_cluster_map_file);
use EFI::Util::CdHit::Parser qw(parse_cdhit_clstr);
use EFI::Util::Colors;


my $colors = new EFI::Util::Colors();


# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();


my $cdhitClusters = parse_cdhit_clstr($opts->{cdhit_file});

my (undef, $clusterToSeqMap) = parse_cluster_map_file($opts->{cluster_map});
my $clusterMap = invert_cluster_map($clusterToSeqMap);




open my $fh, ">", $opts->{table_file} or die "Unable to write cdhit table to '$opts->{table_file}': $!";

my $colorIdx = 0;
foreach my $cdhitClusterId (sort keys %$cdhitClusters) {
    my $color = $colors->getColor($colorIdx);
    $colorIdx++;

    my $data = $cdhitClusters->{$cdhitClusterId};

    foreach my $member (@{ $data->{members} }) {
        my $clusterNum = $clusterMap->{$member} // "N/A";
        $fh->print(join("\t", $clusterNum, $data->{representative}, $member, $color), "\n");
    }
}

close $fh;













sub validateAndProcessOptions {
    my $optParser = new EFI::Options(app_name => $0, desc => "Creates a table of CD-HIT clusters output from ShortBRED to cluster number and a color");

    $optParser->addOption("cdhit-file=s", 1, "path to CD-HIT .clstr file output from ShortBRED", OPT_FILE);
    $optParser->addOption("cluster-map=s", 1, "path to file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("table-file=s", 1, "path to output file", OPT_FILE);

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    my $opts = $optParser->getOptions();

    return $opts;
}

