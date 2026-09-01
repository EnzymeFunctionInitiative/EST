
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Options;
use EFI::Util::FileStats qw(save_stats);




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




my $numConsensusWithHits = computeHits($opts->{protein_abundance});

my $stats = {
    num_cons_seq_with_hits => $numConsensusWithHits,
};

save_stats($opts->{stats}, $stats);


















sub computeHits {
    my $file = shift;

    open my $fh, "<", $file or die "Unable to read file '$file': $!";

    my $count = 0;
    while (my $line = <$fh>) {
        my ($idPart, @parts) = split(m/\t/, $line);
        my ($cluster, $id) = split(m/\|/, $idPart);

        my $sum = 0;
        $sum += $_ for (@parts);

        $count++ if $sum > 0;
    }

    close $fh;

    return $count;
}


sub validateAndProcessOptions {

    my $optParser = new EFI::Options(app_name => $0, desc => "Outputs a file containing statistics for the ShortBRED-Quantify computation");

    $optParser->addOption("protein-abundance=s", 1, "path to a file containing protein abundance values", OPT_FILE);
    $optParser->addOption("stats=s", 1, "path to an output file in JSON format to save statistics to", OPT_FILE);

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    return $optParser->getOptions();
}

