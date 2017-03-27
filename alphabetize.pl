#!/usr/bin/env perl

#this program takes the two accessions from a blast entry an then puts them back in alphabetical order
#this is done because otherwise we have to create a potentially huge hash that uses a lot of RAM
#essentially puts forward and reverse matches to the accessions are in the same order
#later sorted with linux sort and then filtered so we do not have to do a lot of in memory sorting
#this was a significant problem, especially with larger datasets
#version 0.9.4  program created

use Getopt::Long;


$result=GetOptions ("in=s" => \$in,
		    "fasta=s" => \$fasta,
		    "out=s"  => \$out);

open IN, $in or die "cannot open alphabetize input file\n";
open OUT, ">$out" or die "cannot write to output file\n";

open FASTA, $fasta or die "Could not open fasta $fasta\n";

$sequence="";
while (<FASTA>){
  $line=$_;
  chomp $line;
  if($line=~/^>(\w{6,10})$/  or $line=~/^>(\w{6,10}\:\d+\:\d+)$/){
    $seqlengths{$key}=length $sequence;
    $sequence="";
    $key=$1;
  }else{
    $sequence.=$line;
  }
}
$seqlengths{$key}=length $sequence;
close FASTA;

while(<IN>){
  $line=$_;
  chomp $line;
  $line=~/^([A-Za-z0-9:]+)\t([A-Za-z0-9:]+)\t(.*)$/;
  if($1 lt $2){
    print OUT "$line\t$seqlengths{$1}\t$seqlengths{$2}\n";
    #print "forward\n";
  }else{
    print OUT "$2\t$1\t$3\t$seqlengths{$2}\t$seqlengths{$1}\n";
    #print "reverse\n";
  }
}