#!/bin/env perl

#version 0.9.2 no changes to this file

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use DBD::SQLite;

$db=$ENV{'EFIEST'}."/data_files/uniprot_combined.db";
#$db="/quest_data/";
$result=GetOptions ("fasta=s"		=> \$fasta,
		    "struct=s"		=> \$struct,
		    "taxid=s"		=> \$taxid
		    );

open(FASTA, ">$fasta") or die "could not create fasta file $fasta\n";
open(STRUCT, ">$struct") or die "could not create struct file $struct\n";
print "database $db\n";
my $dbh = DBI->connect("dbi:SQLite:$db","","");
@taxids=split /,/, $taxid;
foreach $taxid (@taxids){
  print "getting resuts for $taxid\n";
  $count=0;
  $sth= $dbh->prepare("select * from annotations where Taxonomy_ID = '$taxid'");
  $sth->execute;
  while($row = $sth->fetch){
    print STRUCT $row->[0]."\n\tUniprot_ID\t".$row->[1]."\n\tSTATUS\t".$row->[2]."\n\tSequence_Length\t".$row->[3]."\n\tTaxonomy_ID\t".$row->[4]."\n\tGDNA\t".$row->[5]."\n\tDescription\t".$row->[6]."\n\tOrganism\t".$row->[7]."\n\tDomain\t".$row->[8]."\n\tGN\t".$row->[9]."\n\tPFAM\t".$row->[10]."\n\tPDB\t".$row->[11]."\n\tIPRO\t".$row->[12]."\n\tGO\t".$row->[13]."\n\tGI\t".$row->[14]."\n\tHMP_Body_Site\t".$row->[15]."\n\tHMP_Oxygen\t".$row->[16]."\n\tEFI_ID\t".$row->[17]."\n\tSEQ\t".$row->[18]."\n";
    print FASTA ">".$row->[0]."\n".$row->[18]."\n";
    $count++;
    #print STRUCT "$element\t$id\t$status\t$size\t$OX\t$GDNA\t$DE\t$OS\t$OC\t$GN\t$PFAM\t$PDB\t$IPRO\t$GO\t$giline\t$TID\t$sequence\n";
  }
  print "$taxid has $count matches\n";
}

close FASTA;
close STRUCT;