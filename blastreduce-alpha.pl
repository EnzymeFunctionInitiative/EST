#!/usr/bin/env perl

#version 0.1, the make it work version
#eventually will be merged into step_s.1-chopblast
#version 0.8.5 Changed the blastfile loop from foreach to while to reduce memory
#version 0.9.1 After much thought, this step of the program will remain seperate
#version 0.9.1 Renamed blastreduce.pl from step_2.2-filterblast.pl
#version 0.9.2 Modifiied to accept 6-10 digit accessions
#version 0.9.4 Modified to remove a line if the first two columns are the same as the prior line, this allows removing dups through sorting

use Getopt::Long;
use strict;
use warnings;


my ($blast, $out);
my $result = GetOptions(
    "blast=s"   => \$blast,
    "out=s"     => \$out,
);


if (not $blast or not -f $blast) {
    die "-blast blast file input must be specified";
}
if (not $out) {
    die "-out output file must be specified";
}


open (BLASTFILE, $blast) or die "cannot open blastfile $blast for reading: $!";
open (OUT, ">$out") or die "cannot write to output file $out: $!";

my ($first, $second) = ("", "");
while (my $line = <BLASTFILE>) {
    chomp $line;
    $line =~ /^([a-zA-Z0-9\:]+)\t([a-zA-Z0-9\:]+)/;
    unless ($1 eq $first and $2 eq $second) {
        print OUT "$line\n";
        $first = $1;
        $second = $2;
    }
}

close BLASTFILE;


