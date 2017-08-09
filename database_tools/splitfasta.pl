#!/usr/bin/env perl

#version 0.5.0  fixed a problem where one less file was created if number of sequences were around the value of np
#version 0.8.1  rewrote program to use an array of filehandles instead of chopping into parts.
#version 0.9.0  made program more generic so that it can split up any fasta file into N parts, useful for generating pdb blast info

use Getopt::Long;


$result=GetOptions ("source=s" => \$source,
		    "parts=i"  => \$parts,
		    "tmp=s"    => \$tmpdir);

mkdir $tmpdir;

#open all the filehandles and store them in an arry of $parts elements
@filehandles;
for($i=0;$i<$parts;$i++){
  $filenumber=$i+1;
  local *FILE;
  open(FILE, ">$tmpdir/fracfile-$filenumber.fa") or die "could not create fractional blast file $tmpdir/fracfile-$filenumber.fa\n";
  push(@filehandles, *FILE);
}

#ready through sequences.fa and write each sequence to different filehandle in @filehandles in roundrobin fashion
open(SEQUENCES, $source) or die "could not open sequence file $source\n";
$sequence="";
$arrayid=0;
while (<SEQUENCES>){
#  print "$arrayid\n"; #for troubleshooting
  $line=$_;
  if($line=~/^>/ and $sequence ne ""){
    print {@filehandles[$arrayid]} $sequence;
    $sequence=$line;
    $arrayid++;
    if($arrayid >= scalar @filehandles){
      $arrayid=0;
    }
  }else{
    $sequence.=$line;
  }
}
