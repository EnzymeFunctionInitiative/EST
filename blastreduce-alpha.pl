#!/usr/bin/env perl

#version 0.1, the make it work version
#eventually will be merged into step_s.1-chopblast
#version 0.8.5 Changed the blastfile loop from foreach to while to reduce memory
#version 0.9.1 After much thought, this step of the program will remain seperate
#version 0.9.1 Renamed blastreduce.pl from step_2.2-filterblast.pl
#version 0.9.2 Modifiied to accept 6-10 digit accessions
#version 0.9.4 moved searches hash to disk by using DBM::Deep

use Getopt::Long;


$result=GetOptions ("fasta=s" => \$fasta,
		    "blast=s"  => \$blast,
		    "out=s" => \$out);

%seqlengths=();

open FASTA, $fasta or die "Could not open fasta file $fasta\n";

$sequence="";
while (<FASTA>){
  $line=$_;
  chomp $line;
  if($line=~/^>(\w{6,10})/){
    $seqlengths{$key}=length $sequence;
    $sequence="";
    $key=$1;
  }else{
    $sequence.=$line;
  }
}
$seqlengths{$key}=length $sequence;
close FASTA;

open(BLASTFILE,$blast) or die "Could not open blast output $blast\n";
open(OUT,">$out") or die "Could not write to $out\n";
$first="";
$second="";

while (<BLASTFILE>){
  $line=$_;
  chomp $line;
  $line=~/^(\w+)\t(\w+)/;
  unless($1 eq $first and $2 eq $second){
    print OUT "$line\n";
    $first=$1;
    $second=$2;
  }
}

close BLASTFILE;


