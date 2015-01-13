#!/usr/bin/env perl

#added in version 0.4

use Getopt::Long;

$result=GetOptions ("in=s"   => \$in,
		    "out=s"  => \$out,
		    "high=i" => \$high,
		    "low=i"  => \$low);

open IN, $in or die "Could not open $in\n";
open OUT, ">$out" or die "Could write to $out\n";

$length=0;
$sequence=0;
foreach $line (<IN>){
  if($line=~/^>/){
    #print "sequence: $sequence\n";
    $length=length($sequence);
    #print "$length\n";
    unless( $length==0){
      if($length<$high and $length>$low){
        chomp $head;
        #print "keep $head, length $length\n";
        print OUT "$head\n$sequence";
      }else{
        chomp $head;
        #print "throw $head, length $length\n";
      }
    }
    $head=$line;
    $sequence="";
  }else{
    $sequence.=$line;
  }
}
