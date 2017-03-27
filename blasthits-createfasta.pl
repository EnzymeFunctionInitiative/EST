#!/usr/bin/env perl

use Getopt::Long;
use DBD::SQLite;
use DBD::mysql;
use File::Slurp;

$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
eval $configfile;

$result=GetOptions (	"fasta=s"	=> \$fasta,
			"accessions=s"	=> \$accessions
		    );

print "$data_files/combined.fasta";

open(FASTA, ">$fasta") or die "could not write to fasta file $fasta\n";
open(ACC, $accessions) or die "could not read accession file $accessions\n";

while(<ACC>){
  $line=$_;
  chomp $line;
  @sequences=split "\n", `fastacmd -d $data_files/combined.fasta -s $line`;
  foreach $sequence (@sequences){
    $sequence=~s/^>\w\w\|(\w{6,10})\|.*/>$1/;
    print FASTA "$sequence\n";
  }
}