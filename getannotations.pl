#!/usr/bin/env perl

#version 0.9.2 no changes to this file
#version 0.9.4 modifications due to removing sequence and classi fields and addition of uniprot_description field

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use DBD::SQLite;
use DBD::mysql;
use File::Slurp;


$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
eval $configfile;

$result=GetOptions ("fasta=s"		=> \$fasta,
		    "out=s"		=> \$out,
		    "userdat=s"		=> \$userdat
		    );
print "$fasta\n";

@accessions=apply {chomp $_} apply {$_=~s/:\d+:\d+//} apply {$_=~s/^>//} `grep "\>" $fasta`;

open OUT, ">$out" or die "cannot write struct.out file $out\n";


foreach $accession (@accessions){
  #print "$accession\n";
  unless($accession=~/^z/){
    $sth= $dbh->prepare("select * from annotations where accession = '$accession'");
    $sth->execute;
    $row = $sth->fetch;
    print OUT $row->[0]."\n\tUniprot_ID\t".$row->[1]."\n\tSTATUS\t".$row->[2]."\n\tSequence_Length\t".$row->[3]."\n\tTaxonomy_ID\t".$row->[4]."\n\tGDNA\t".$row->[5]."\n\tDescription\t".$row->[6]."\n\tSwissprot_Description\t".$row->[7]."\n\tOrganism\t".$row->[8]."\n\tDomain\t".$row->[9]."\n\tGN\t".$row->[10]."\n\tPFAM\t".$row->[11]."\n\tPDB\t".$row->[12]."\n\tIPRO\t".$row->[13]."\n\tGO\t".$row->[14]."\n\tGI\t".$row->[15]."\n\tHMP_Body_Site\t".$row->[16]."\n\tHMP_Oxygen\t".$row->[17]."\n\tEFI_ID\t".$row->[18]."\n\tEC\t".$row->[19]."\n\tPHYLUM\t".$row->[20]."\n\tCLASS\t".$row->[21]."\n\tORDER\t".$row->[22]."\n\tFAMILY\t".$row->[23]."\n\tGENUS\t".$row->[24]."\n\tSPECIES\t".$row->[25]."\n\tCAZY\t".$row->[26]."\n";
  }
}

close OUT;

if($userdat=~/\w+/ and -s $userdat){
  #add user supplied dat info tio struct.out
  system("cat $userdat >> $out");
}