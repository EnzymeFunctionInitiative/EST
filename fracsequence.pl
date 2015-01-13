#!/usr/bin/env perl

#version 0.5.0  fixed a problem where one less file was created if number of sequences were around the value of np
#version 0.8.1  rewrote program to use an array of filehandles instead of chopping into parts.
#version 0.9.2	no changes

use Getopt::Long;


$result=GetOptions ("np=i"     => \$np,
		    "tmp=s"    => \$tmpdir);

#open all the filehandles and store them in an arry of $np elements
@filehandles;
for($i=0;$i<$np;$i++){
  $filenumber=$i+1;
  local *FILE;
  open(FILE, ">$tmpdir/fracfile-$filenumber.fa") or die "could not create fractional blast file $tmpdir/fracfile-$filenumber.fa\n";
  push(@filehandles, *FILE);
}

#ready through sequences.fa and write each sequence to different filehandle in @filehandles in roundrobin fashion
open(SEQUENCES, "$tmpdir/sequences.fa") or die "could not open sequence file $tmpdir/sequences.fa\n";
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
