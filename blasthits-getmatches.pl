#!/usr/bin/env perl

use Getopt::Long;
use DBD::SQLite;
use DBD::mysql;
use File::Slurp;

$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
eval $configfile;

$result=GetOptions (	"blastfile=s"	=> \$blastfile,
			"accessions=s"	=> \$accessions,
			"max=i"		=> \$max
		    );

open(ACCESSIONS, ">$accessions") or die "Couldn not write accession list $accessions\n";
open(INITBLAST, $blastfile) or die "Cannot open sorted initial blast query $blastfile\n";
$count=0;
@accessions=();
while (<INITBLAST>){
  $line=$_;
  @lineary=split /\s+/, $line;
  @lineary[1]=~/\|(\w+)\|/;
  $accession=$1;
  if($count==0){
    print "Top hit is $accession\n";
  }
  print ACCESSIONS "$accession\n";
  push @accessions, $accession; 
  $count++;
  if($count>=$max){
    last;
  }
}
close INITBLAST;
close ACCESSIONS;