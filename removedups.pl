#!/usr/bin/env perl

use Getopt::Long;
#use DBD::SQLite;
#use DBD::mysql;
#use File::Slurp;

#$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
#eval $configfile;

$result=GetOptions (	"in=s"	=> \$in,
			"out=s"	=> \$out
		    );

open(IN, $in) or die "could not open input file $in.\n";
open(OUT, ">$out") or die "could not write to output file $out.";

while(<IN>){
  $line=$_;
  $line=~/^(\w{6,10})\t(\w{6,10})/;
  unless($1 eq $2){
    print OUT $line;
  }
}