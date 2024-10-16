#!/usr/bin/env perl

#version 0.5.0  fixed a problem where one less file was created if number of sequences were around the value of np
#version 0.8.1  rewrote program to use an array of filehandles instead of chopping into parts.
#version 0.9.0  made program more generic so that it can split up any fasta file into N parts, useful for generating pdb blast info

use Getopt::Long;

use strict;

my ($source, $parts, $outputDir, $help);
my $result = GetOptions (
    "source=s" => \$source,
    "parts=i"  => \$parts,
    "help" => \$help);

if ($help) {
    print 'Usage: perl split_fasta.pl --source SOURCE --parts PARTS

Description:
    Splits a FASTA file into approximately evenly-sized shards by round-robin
    distribution. Shards will be named "fracfile-<number>.fa". <number> starts at 1.

Options:
    --source        FASTA file to split
    --parts         number of shards to create
    ';
    exit 0;
}

die "Input sequence file to split up not valid or not provided" if not -f $source;
die "Number of parts to split paramter not provided" if not $parts;


#open all the filehandles and store them in an arry of $parts elements
my @filehandles;
for(my $i = 0; $i < $parts; $i++){
    my $filenumber = $i + 1;
    local *FILE;
    open(FILE, ">fracfile-$filenumber.fa") or die "could not create fractional blast file $outputDir/fracfile-$filenumber.fa\n";
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


