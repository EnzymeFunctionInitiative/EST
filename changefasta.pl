#!/usr/bin/env perl

open(IN, @ARGV[0]) or die "could not open input file @ARGV[0]\n";
open(OUT, ">@ARGV[1]") or die "could not open input file @ARGV[1]\n";

$counter=0;
while(<IN>){
  $line=$_;
  if($line=~/>/){
    print OUT '>';
    printf OUT '%06s',$counter;
    print OUT "\n";
    $counter++;
  }else{
    print OUT $line;
  }
}