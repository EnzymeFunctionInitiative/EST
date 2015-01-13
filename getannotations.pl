#!/usr/bin/env perl

#version 0.9.2 no changes to this file

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use DBD::SQLite;
use DBD::mysql;
use File::Slurp;

#removed in favor of cfg file
#$db=$ENV{'EFIEST'}."/data_files/uniprot_combined.db";
#my $dbh = DBI->connect("dbi:SQLite:$db","","");
$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
eval $configfile;

$result=GetOptions ("fasta=s"		=> \$fasta,
		    "out=s"		=> \$out,
		    "userdat=s"		=> \$userdat
		    );
print "$fasta\n";

@accessions=apply {chomp $_} apply {$_=~s/^>//} `grep "\>" $fasta`;

open OUT, ">$out" or die "cannot write struct.out file $out\n";


foreach $accession (@accessions){
  #print "$accession\n";
  $sth= $dbh->prepare("select * from annotations where accession = '$accession'");
  $sth->execute;
  $row = $sth->fetch;
  print OUT $row->[0]."\n\tUniprot_ID\t".$row->[1]."\n\tSTATUS\t".$row->[2]."\n\tSequence_Length\t".$row->[3]."\n\tTaxonomy_ID\t".$row->[4]."\n\tGDNA\t".$row->[5]."\n\tDescription\t".$row->[6]."\n\tOrganism\t".$row->[7]."\n\tDomain\t".$row->[8]."\n\tGN\t".$row->[9]."\n\tPFAM\t".$row->[10]."\n\tPDB\t".$row->[11]."\n\tIPRO\t".$row->[12]."\n\tGO\t".$row->[13]."\n\tGI\t".$row->[14]."\n\tHMP_Body_Site\t".$row->[15]."\n\tHMP_Oxygen\t".$row->[16]."\n\tEFI_ID\t".$row->[17]."\n\tEC\t".$row->[18]."\n\tClassi\t".$row->[19]."\n\tPHYLUM\t".$row->[20]."\n\tCLASS\t".$row->[21]."\n\tORDER\t".$row->[22]."\n\tFAMILY\t".$row->[23]."\n\tGENUS\t".$row->[24]."\n\tSPECIES\t".$row->[25]."\n\tCAZY\t".$row->[26]."\n\tSEQ\t".$row->[27]."\n";
#  print STRUCT "$element\t$id\t$status\t$size\t$OX\t$GDNA\t$DE\t$OS\t$OC\t$GN\t$PFAM\t$PDB\t$IPRO\t$GO\t$giline\t$hmpsite\t$hmpoxygen\t                                                                                                                                                                                                                                                                                                                  $TID\t$EC\t$classi\t                                                       $phylum\t$class\t$order\t                                                       $family\t$genus\t$species\t$cazy\t$sequence\n";

  #print STRUCT "$element\t$id\t$status\t$size\t$OX\t$GDNA\t$DE\t$OS\t$OC\t$GN\t$PFAM\t$PDB\t$IPRO\t$GO\t$giline\t$TID\t$sequence\n";
}

close OUT;

if($userdat=~/\w+/ and -s $userdat){
  #add user supplied dat info tio struct.out
  system("cat $userdat >> $out");
}