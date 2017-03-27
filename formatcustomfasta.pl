#!/usr/bin/env perl

#perl module for loading command line options
use Getopt::Long;

$result=GetOptions ("in=s"		=> \$in,
		    "out=s"		=> \$out,
		    "dat=s"		=> \$dat);

open(IN, $in) or die "Cannot open input file in\n";
open(OUT, ">$out") or die "Cannot write fasta output file $out\n";
open(DAT, ">$dat") or die "Cannot write dat output file $dat\n";

$count=0;
$length=0;

while(<IN>){
  $line=$_;
  if($line=~s/^>//){
    $lzerocount=sprintf("%6d",$count);
    $lzerocount=~tr/ /z/;
    print OUT ">$lzerocount\n";
    chomp $line;
    if($length>0){
      print DAT "\tSequence_Length\t$length\n";
      $length=0;
    }
    print DAT "$lzerocount\n\tDescription\t$line\n";
    $count++;
  }else{
    print OUT $line;
    chomp($line);
    $line=~s/\s//g;
    $length+=length($line);
  }
}
print DAT "\tSequence_Length\t$length\n";