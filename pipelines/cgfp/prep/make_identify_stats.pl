
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Options;
use EFI::Util::FileStats qw(save_stats);




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




my $numSequences = countFile($opts->{condensed_fasta}, qr/^>/);

my $numMarkers = countFile($opts->{markers}, qr/^>/);

my $numCdhitClusters = countFile($opts->{cdhit_file}, qr/^>/);

my $stats = {
    num_cdhit_clusters => $numCdhitClusters,
    num_markers => $numMarkers,
    num_unique_seq => $numSequences,
};

save_stats($opts->{stats}, $stats);


















#
# countFile
#
# Count the number of lines matching a specific pattern in the input file.
#
# Parameters:
#    $file - path to input file
#    $pattern - regex pattern to evaluate every line on; if matched, the line is counted
#
# Returns:
#    number of matches in the file
#
sub countFile {
    my $file = shift;
    my $pattern = shift;

    open my $fh, "<", $file or die "Unable to read file '$file': $!";

    my $count = 0;
    while (my $line = <$fh>) {
        $count++ if $line =~ $pattern;
    }

    close $fh;

    return $count;
}


sub validateAndProcessOptions {

    my $optParser = new EFI::Options(app_name => $0, desc => "Outputs a file containing statistics for the ShortBRED-Identify computation");

    $optParser->addOption("condensed-fasta=s", 1, "path to a file containing the unique set of sequences used in the computation", OPT_FILE);
    $optParser->addOption("markers=s", 1, "path to a file with the results of the ShortBRED-Identify marker computation", OPT_FILE);
    $optParser->addOption("cdhit-file=s", 1, "path to a file with the results of the ShortBRED-Identify CD-HIT computation", OPT_FILE);
    $optParser->addOption("stats=s", 1, "path to an output file in JSON format to save statistics to", OPT_FILE);

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    return $optParser->getOptions();
}

