#!/bin/env perl

use Getopt::Long;

$result=GetOptions ("in=s"		=> \$in,
		    "out=s"		=> \$out);

open(IN, $in) or die "cannot open file $in\n";
open(OUT, ">$out") or die "cannot write file $out\n";

while (<IN>){
  $line=$_;
  chomp $line;
  @line=split /\t/, $line;
  @line[0]=~/\w+\|(\w+)\|\w+/;
  $acc=$1;
  @line[1]=~/\w+\|\w+\|\w+\|(\w+)\|\w+/;
  $pdb=$1;
  print OUT "$acc\t$pdb\t@line[10]\n";
}