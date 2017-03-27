#!/bin/env perl

#version 0.9.2 no changes to this file
#version 0.9.5 fixed a bug in creating struct.out file where not all annotation information was being written

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

#$db="/quest_data/";
$result=GetOptions ("fasta=s"		=> \$fasta,
		    "struct=s"		=> \$struct,
		    "taxid=s"		=> \$taxid
		    );

open(FASTA, ">$fasta") or die "could not create fasta file $fasta\n";
open(STRUCT, ">$struct") or die "could not create struct file $struct\n";
print "database $db\n";

@accessions=();
$perpass=$ENV{'EFIPASS'};
@taxids=split /,/, $taxid;
foreach $taxid (@taxids){
  print "getting resuts for $taxid\n";
  $count=0;
  $sth= $dbh->prepare("select * from annotations where Taxonomy_ID = '$taxid'");
  $sth->execute;
  while($row = $sth->fetch){
    print STRUCT $row->[0]."\n\tUniprot_ID\t".$row->[1]."\n\tSTATUS\t".$row->[2]."\n\tSequence_Length\t".$row->[3]."\n\tTaxonomy_ID\t".$row->[4]."\n\tGDNA\t".$row->[5]."\n\tDescription\t".$row->[6]."\n\tSwissprot_Description\t".$row->[7]."\n\tOrganism\t".$row->[8]."\n\tDomain\t".$row->[9]."\n\tGN\t".$row->[10]."\n\tPFAM\t".$row->[11]."\n\tPDB\t".$row->[12]."\n\tIPRO\t".$row->[13]."\n\tGO\t".$row->[14]."\n\tGI\t".$row->[15]."\n\tHMP_Body_Site\t".$row->[16]."\n\tHMP_Oxygen\t".$row->[17]."\n\tEFI_ID\t".$row->[18]."\n\tEC\t".$row->[19]."\n\tPHYLUM\t".$row->[20]."\n\tCLASS\t".$row->[21]."\n\tORDER\t".$row->[22]."\n\tFAMILY\t".$row->[23]."\n\tGENUS\t".$row->[24]."\n\tSPECIES\t".$row->[25]."\n\tCAZY\t".$row->[26]."\n";
    #print STRUCT $row->[0]."\n\tUniprot_ID\t".$row->[1]."\n\tSTATUS\t".$row->[2]."\n\tSequence_Length\t".$row->[3]."\n\tTaxonomy_ID\t".$row->[4]."\n\tGDNA\t".$row->[5]."\n\tDescription\t".$row->[6]."\n\tSwissProt_Description\t".$row->[7]."\n\tOrganism\t".$row->[8]."\n\tDomain\t".$row->[9]."\n\tGN\t".$row->[10]."\n\tPFAM\t".$row->[11]."\n\tPDB\t".$row->[12]."\n\tIPRO\t".$row->[13]."\n\tGO\t".$row->[14]."\n\tGI\t".$row->[15]."\n\tHMP_Body_Site\t".$row->[16]."\n\tHMP_Oxygen\t".$row->[17]."\n\tEFI_ID\t".$row->[18]."\n";
    #print FASTA ">".$row->[0]."\n".$row->[18]."\n";
    push @accessions,$row->[0];
    $count++;
    #print STRUCT "$element\t$id\t$status\t$size\t$OX\t$GDNA\t$DE\t$OS\t$OC\t$GN\t$PFAM\t$PDB\t$IPRO\t$GO\t$giline\t$TID\t$sequence\n";
  }
  print "$taxid has $count matches\n";
}

open FASTA, ">$fasta" or die "Cannot write to output fasta $out\n";
while(scalar @accessions){
  @batch=splice(@accessions, 0, $perpass);
  $batchline=join ',', @batch;
  @sequences=split /\n/, `fastacmd -d $data_files/combined.fasta -s $batchline`;
  foreach $sequence (@sequences){ 
    $sequence=~s/^>\w\w\|(\w{6,10})\|.*/>$1/;
    print FASTA "$sequence\n";
  }
  
}
close FASTA;
close STRUCT;