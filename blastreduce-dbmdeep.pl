#!/usr/bin/env perl

#version 0.1, the make it work version
#eventually will be merged into step_s.1-chopblast
#version 0.8.5 Changed the blastfile loop from foreach to while to reduce memory
#version 0.9.1 After much thought, this step of the program will remain seperate
#version 0.9.1 Renamed blastreduce.pl from step_2.2-filterblast.pl
#version 0.9.2 Modifiied to accept 6-10 digit accessions
#version 0.9.4 moved searches hash to disk by using DBM::Deep

use DBM::Deep;
use Getopt::Long;


$filename=@ARGV[0];
$blastfile=@ARGV[1];

%seqlengths=();

open FASTA, $blastfile or die "Could not open $blastfile\n";

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

open(BLASTFILE,$filename) or die "Could not open $filename\n";

%searches=();
$db=DBM::Deep->new("searches.db");

while (<BLASTFILE>){
  $line=$_;
  unless($line=~/^\#/){
    chomp $line;
    my @lineary=split /\t/,$line;
    my $sequencea=@lineary[0];
    my $sequenceb=@lineary[1];
    #unless(defined $searches{"$sequencea$sequenceb"}or defined $searches{"$sequenceb$sequencea"} ){
    unless(defined $db->{"$sequencea$sequenceb"} or defined $db->{"$sequenceb$sequencea"}){
      #$searches{"$sequencea$sequenceb"}=1;
      $db->{"$sequencea$sequenceb"}=1;
      #$id=@lineary[11]/100;
      $id=@lineary[2]/100;
      #print "@lineary[0]\t@lineary[1]\t@lineary[2]\t".@lineary[4]*@lineary[5]."\t@lineary[6]\t$id\t@lineary[3]\t@lineary[8]\t@lineary[9]\t@lineary[10]\t@lineary[4]\t@lineary[5]\n";
      print "@lineary[0]\t@lineary[1]\t@lineary[11]\t$id\t$seqlengths{@lineary[0]}\t$seqlengths{@lineary[1]}\n";
    }
  }
}

close BLASTFILE;


