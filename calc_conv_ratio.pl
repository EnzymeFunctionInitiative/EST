#!/usr/bin/env perl

#program to re-add sequences removed by initial cdhit
#version 0.9.3 Program created

use strict;

use Getopt::Long;


my ($edgeIn, $seqIn);
my $result = GetOptions(
    "edge-file=s"   => \$edgeIn,
    "seq-file=s"    => \$seqIn,
);


die "Required -edge-file argument missing" if not -f $edgeIn;
die "Required -seq-file argument missing" if not -f $seqIn;


my $numLines = `wc -l $edgeIn`;
chomp $numLines;

my $numSeq = `grep \\> $seqIn | wc -l`;
chomp $numSeq;

my $numerator = $numLines * 2;
my $denominator = int($numSeq * ($numSeq - 1));
my $convRatio = 1;
if ($denominator != 0) {
    $convRatio = $numerator / $denominator;
}

print $convRatio;

