#!/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use Cwd;

use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../../../lib";

use EFI::Annotations::Fields qw(INPUT_SEQ_ID);
use EFI::Import::Config::Defaults;



my ($blastQueryFile, $outputSeqFile, $outputDir, $wantHelp);
my $result = GetOptions(
    "blast-query-file=s" => \$blastQueryFile,
    "output-sequence-file=s" => \$outputSeqFile,
    "output-dir=s" => \$outputDir,
    "help" => \$wantHelp,
);

printHelp() if $wantHelp;

$outputDir = getcwd() if not $outputDir;

checkArgs();



open my $queryFh, "<", $blastQueryFile or die "Unable to read blast query file $blastQueryFile: $!";
open my $outFh, ">>", $outputSeqFile or die "Unable to append to sequence file $outputSeqFile: $!";

$outFh->print(">" . &INPUT_SEQ_ID, "\n");
while (my $line = <$queryFh>) {
    next if $line =~ m/^>/;
    $outFh->print($line);
}

close $outFh;
close $queryFh;



sub checkArgs {
    my $fail = 0;
    if (not $blastQueryFile or not -f $blastQueryFile) {
        print "Require --blast-query-file containing the FASTA sequence to use for the BLAST\n";
        $fail = 1;
    }
    if (not $outputSeqFile) {
        $outputSeqFile = get_default_path("all_sequences", $outputDir);
    }

    if ($fail) {
        die "\n";
    }
}


sub printHelp {
    print <<HELP;
$0 --blast-query-file path_to_file [--output-sequence-file <path/to/output/sequences/file.fasta>]
    [--output-dir <path/to/output/dir>]
HELP
    exit(0);
}






