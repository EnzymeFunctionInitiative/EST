#!/usr/bin/env perl

# This program takes the two accessions from a blast entry an then puts them back in alphabetical order
# This is done because otherwise we have to create a potentially huge hash that uses a lot of RAM
# Essentially puts forward and reverse matches to the accessions are in the same order
# Later sorted with linux sort and then filtered so we do not have to do a lot of in memory sorting
# This was a significant problem, especially with larger datasets
#
# The input to this program is the following (columns from the BLAST output):
#
# SUBJECT QUERY PCT_ID ALIGNMENT_LEN BIT_SCORE
#
# This program also adds the sequence lengths to the output lines.  The output columns from this file
# are as follows:
#
# SUBJECT QUERY PCT_ID ALIGNMENT_LEN BIT_SCORE SUBJECT_LEN QUERY_LEN
#

use Getopt::Long;
use strict;
use warnings;


my ($inputBlast, $inputFasta, $outputBlast);
my $result = GetOptions(
    "in=s"      => \$inputBlast,
    "fasta=s"   => \$inputFasta,
    "out=s"     => \$outputBlast,
);


if (not $inputBlast or not -f $inputBlast) {
    die "-in input blast file must be specified";
}
if (not $inputFasta or not -f $inputFasta) {
    die "-fasta input FASTA sequence file must be specified";
}
if (not $outputBlast) {
    die "-out output file parameter must be specified";
}


open IN, $inputBlast or die "cannot open alphabetize input file $inputBlast: $!";
open OUT, ">$outputBlast" or die "cannot write to output file $outputBlast: $!";
open FASTA, $inputFasta or die "Could not open fasta $inputFasta for reading: $!";

my %seqLen;
my $key = "";
my $sequence = "";
while (my $line = <FASTA>) {
    chomp $line;
    if ($line =~ /^>(\w{6,10})$/ or $line =~ /^>(\w{6,10}\:\d+\:\d+)$/) {
        if ($key) {
            $seqLen{$key} = length $sequence;
        }
        $sequence = "";
        $key = $1;
    } else {
        $sequence .= $line;
    }
}
$seqLen{$key} = length $sequence;
close FASTA;

while (my $line = <IN>) {
    chomp $line;
    $line =~ /^([A-Za-z0-9:]+)\t([A-Za-z0-9:]+)\t(.*)$/;
    my ($query, $subject, $values) = ($1, $2, $3);
    # Compare the IDs. We sort them.
    if ($1 lt $2) {
        # Forward
        print OUT "$query\t$subject\t$values\t$seqLen{$1}\t$seqLen{$2}\n";
    } else {
        # Reverse
        print OUT "$subject\t$query\t$values\t$seqLen{$2}\t$seqLen{$1}\n";
    }
}

close OUT;
close IN;

