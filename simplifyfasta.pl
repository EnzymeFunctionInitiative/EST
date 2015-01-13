#!/usr/bin/env perl

use Getopt::Long;


$result=GetOptions ("out=s"   => \$out,
		    "fasta=s"  => \$fasta);

open FASTA, $fasta or die "could not open file $fasta\n";
open OUT, ">$out" or die "cannot write to $out\n";

print "Reading FASTA file\n";
foreach $line (<FASTA>){
  if($line=~/^>[trsp]{2}\|(\w{6})\|/){
    $line=">$1\n";
  }
  print OUT $line;
}
