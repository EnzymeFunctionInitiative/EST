#!/usr/bin/env perl

use strict;
use Getopt::Long;

my ($blastfile, $accessions, $max);
my $result=GetOptions(
    "blastfile=s"   => \$blastfile,
    "accessions=s"  => \$accessions,
    "max=i"         => \$max,
);

die "Missing required command line arguments" if not $blastfile or not $accessions or not $max;

open(ACCESSIONS, ">$accessions") or die "Could not write accession list $accessions\n";
open(INITBLAST, $blastfile) or die "Cannot open sorted initial blast query $blastfile\n";

my $count=0;
my %accessions=();

while (<INITBLAST>){
    chomp;
    my $line=$_;
    my @parts = split /\s+/, $line;
    $parts[1]=~/\|(\w+)\|/;
    my $accession=$1;
    if($count==0){
        print "Top hit is $accession\n";
    }

    if (exists $accessions{$accession}) {
        print "Found duplicate ID in blast file: $accession ($line)\n";
    } else {
        print ACCESSIONS "$accession\n";
        $count++;
    }

    $accessions{$accession} = 1;
    if($count>=$max){
        last;
    }
}
close INITBLAST;
close ACCESSIONS;


