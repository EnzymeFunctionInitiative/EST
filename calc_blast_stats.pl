#!/usr/bin/env perl


use warnings;
use strict;

use Getopt::Long;


my ($edgeIn, $seqIn, $uniqueSeqIn, $statsFile);
my $result = GetOptions(
    "edge-file=s"           => \$edgeIn,
    "seq-file=s"            => \$seqIn,
    "unique-seq-file=s"     => \$uniqueSeqIn,
    "seq-count-output=s"    => \$statsFile,
);


die "Required -edge-file argument missing" if not -f $edgeIn;
die "Required -seq-file argument missing" if not -f $seqIn;
die "Required -stats-file argument missing" if not $statsFile or not -f $statsFile;

my $numLines = `wc -l $edgeIn`;
$numLines =~ s/^\s*(\d+).*$/$1/s;

my $numSeq = `grep \\> $seqIn | wc -l`;
chomp $numSeq;

my $numUniqueSeq = 0;
if ($uniqueSeqIn and -f $uniqueSeqIn) {
    $numUniqueSeq = `grep \\> $uniqueSeqIn | wc -l`;
    chomp $numUniqueSeq;
}

my $numerator = $numLines * 2;
my $denominator = int($numSeq * ($numSeq - 1));
my $convRatio = 1;
if ($denominator != 0) {
    $convRatio = $numerator / $denominator;
}


open META, ">>", $statsFile or die "Unable to open stats file for appending $statsFile: $!";
print META "ConvergenceRatio\t$convRatio\n";
print META "EdgeCount\t$numLines\n";
print META "UniqueSeq\t$numUniqueSeq\n" if $numUniqueSeq;
close META;

