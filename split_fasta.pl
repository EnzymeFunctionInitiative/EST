#!/usr/bin/env perl

#version 0.5.0  fixed a problem where one less file was created if number of sequences were around the value of np
#version 0.8.1  rewrote program to use an array of filehandles instead of chopping into parts.
#version 0.9.0  made program more generic so that it can split up any fasta file into N parts, useful for generating pdb blast info

use Getopt::Long;

use strict;

my ($source, $parts, $outputDir);
my $result = GetOptions (
    "source=s" => \$source,
    "parts=i"  => \$parts,
    "tmp=s"    => \$outputDir);

die "Input sequence file to split up not valid or not provided" if not -f $source;
die "Number of parts to split paramter not provided" if not $parts;
die "Output directory not provided" if not -d $outputDir;


#open all the filehandles and store them in an arry of $parts elements
my @filehandles;
for(my $i = 0; $i < $parts; $i++){
    my $filenumber = $i + 1;
    local *FILE;
    open(FILE, ">$outputDir/fracfile-$filenumber.fa") or die "could not create fractional blast file $outputDir/fracfile-$filenumber.fa\n";
    push(@filehandles, *FILE);
}

#ready through sequences.fa and write each sequence to different filehandle in @filehandles in roundrobin fashion
open(SEQUENCES, $source) or die "could not open sequence file $source\n";
my $sequence = "";
my $arrayid = 0;
while (<SEQUENCES>){
#  print "$arrayid\n"; #for troubleshooting
    my $line = $_;
    if($line =~ /^>/ and $sequence ne ""){
        print {@filehandles[$arrayid]} $sequence;
        $sequence = $line;
        $arrayid++;
        if($arrayid >= scalar @filehandles){
            $arrayid = 0;
        }
    }else{
        $sequence .= $line;
    }
}
close SEQUENCES;

print {@filehandles[$arrayid]} $sequence;


