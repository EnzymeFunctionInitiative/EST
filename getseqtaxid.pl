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
  while($row = $sth->fetchrow_hashref){
    print STRUCT
            $row->{"accession"} .
            "\n\tUniprot_ID\t" . $row->{"Uniprot_ID"} .
            "\n\tSTATUS\t" . $row->{"STATUS"} .
            "\n\tSequence_Length\t" . $row->{"Squence_Length"} .
            "\n\tTaxonomy_ID\t" . $row->{"Taxonomy_ID"} .
            "\n\tGDNA\t" . $row->{"GDNA"} .
            "\n\tDescription\t" . $row->{"Description"} .
            "\n\tSwissprot_Description\t" . $row->{"SwissProt_Description"} .
            "\n\tOrganism\t" . $row->{"Organism"} .
            "\n\tDomain\t" . $row->{"Domain"} .
            "\n\tGN\t" . $row->{"GN"} .
            "\n\tPFAM\t" . $row->{"PFAM"} .
            "\n\tPDB\t" . $row->{"pdb"} .
            "\n\tIPRO\t" . $row->{"IPRO"} .
            "\n\tGO\t" . $row->{"GO"} .
            "\n\tGI\t" . $row->{"GI"} .
            "\n\tHMP_Body_Site\t" . $row->{"HMP_Body_Site"} .
            "\n\tHMP_Oxygen\t" . $row->{"HMP_Oxygen"} .
            "\n\tEFI_ID\t" . $row->{"EFI_ID"} .
            "\n\tEC\t" . $row->{"EC"} .
            "\n\tPHYLUM\t" . $row->{"Phylum"} .
            "\n\tCLASS\t" . $row->{"Class"} .
            "\n\tORDER\t" . $row->{"TaxOrder"} .
            "\n\tFAMILY\t" . $row->{"Family"} .
            "\n\tGENUS\t" . $row->{"Genus"} .
            "\n\tSPECIES\t" . $row->{"Species"} .
            "\n\tCAZY\t" . $row->{"Cazy"} .
            "\n";
    #print STRUCT $row->{"accession"} .
    #        "\n\tUniprot_ID\t" . $row->{"Uniprot_ID"} .
    #        "\n\tSTATUS\t" . $row->{"STATUS"} .
    #        "\n\tSequence_Length\t" . $row->{"Squence_Length"} .
    #        "\n\tTaxonomy_ID\t" . $row->{"Taxonomy_ID"} .
    #        "\n\tGDNA\t" . $row->{"GDNA"} .
    #        "\n\tDescription\t" . $row->{"Description"} .
    #        "\n\tSwissProt_Description\t" . $row->{"SwissProt_Description"} .
    #        "\n\tOrganism\t" . $row->{"Organism"} .
    #        "\n\tDomain\t" . $row->{"Domain"} .
    #        "\n\tGN\t" . $row->{"GN"} .
    #        "\n\tPFAM\t" . $row->{"PFAM"} .
    #        "\n\tPDB\t" . $row->{"pdb"} .
    #        "\n\tIPRO\t" . $row->{"IPRO"} .
    #        "\n\tGO\t" . $row->{"GO"} .
    #        "\n\tGI\t" . $row->{"GI"} .
    #        "\n\tHMP_Body_Site\t" . $row->{"HMP_Body_Site"} .
    #        "\n\tHMP_Oxygen\t" . $row->{"HMP_Oxygen"} .
    #        "\n\tEFI_ID\t" . $row->{"EFI_ID"} . 
    #        "\n";
    #print FASTA ">" . $row->{"accession"} . "\n" . $row->{"EFI_ID"} . "\n";

    push @accessions,$row->{"accessions"];
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
