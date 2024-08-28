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



my ($blastQueryFile, $outputSeqFile, $outputDir);
my $result = GetOptions(
    "blast-query-file=s" => \$blastQueryFile,
    "output-sequence-file=s" => \$outputSeqFile,
    "output-dir=s" => \$outputDir,
);

$outputDir = getcwd() if not $outputDir;

die "Require --blast-query-file" if not $blastQueryFile or not -f $blastQueryFile;

if (not $outputSeqFile) {
    $outputSeqFile = get_default_path("all_sequences", $outputDir);
}



open my $queryFh, "<", $blastQueryFile or die "Unable to read blast query file $blastQueryFile: $!";
open my $outFh, ">>", $outputSeqFile or die "Unable to append to sequence file $outputSeqFile: $!";

$outFh->print(">" . &INPUT_SEQ_ID, "\n");
while (my $line = <$queryFh>) {
    next if $line =~ m/^>/;
    $outFh->print($line);
}

close $outFh;
close $queryFh;


