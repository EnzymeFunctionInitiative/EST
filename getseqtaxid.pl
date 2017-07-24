#!/bin/env perl

#version 0.9.2 no changes to this file
#version 0.9.5 fixed a bug in creating struct.out file where not all annotation information was being written

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use DBD::SQLite;
use DBD::mysql;
use File::Slurp;
use FindBin;
use lib "$FindBin::Bin/lib";
use Biocluster::Database;
use Annotations;

#removed in favor of cfg file
#$db=$ENV{'EFIEST'}."/data_files/uniprot_combined.db";
#my $dbh = DBI->connect("dbi:SQLite:$db","","");
#$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
#eval $configfile;

#$db="/quest_data/";
my ($fasta, $struct, $taxid, $configFile);
my $result = GetOptions(
    "fasta=s"       => \$fasta,
    "struct=s"      => \$struct,
    "taxid=s"       => \$taxid,
    "config=s"      => \$configFile,
);

die "Command-line arguments are not valid: missing -config=config_file_path argument" if not defined $configFile or not -f $configFile;
die "Environment variables not set properly: missing EFIDB variable" if not exists $ENV{EFIDB};

my $db = new Biocluster::Database(config_file_path => $configFile);
my $dbh = $db->getHandle();


open(STRUCT, ">$struct") or die "could not create struct file $struct\n";
print "database $ENV{EFIDB}\n";

my @accessions = ();
my $perpass = $ENV{EFIPASS};
my @taxids = split /,/, $taxid;

foreach my $taxid (@taxids){
    print "getting resuts for $taxid\n";
    my $count = 0;

    my $sql = Annotations::build_taxid_query_string($taxid);
    #$sql = "select * from annotations where Taxonomy_ID = '$taxid'";
    my $sth = $dbh->prepare($sql);

    $sth->execute;
    while ($row = $sth->fetchrow_hashref) {
        print STRUCT Annotations::build_annotations($row);
#            $row->{"accession"} .
#            "\n\tSTATUS\t" . $row->{"STATUS"} .
#            "\n\tSequence_Length\t" . $row->{"Squence_Length"} .
#            "\n\tTaxonomy_ID\t" . $row->{"Taxonomy_ID"} .
#            "\n\tP01_gDNA\t" . $row->{"GDNA"} .
#            "\n\tDescription\t" . $row->{"Description"} .
#            "\n\tSwissprot_Description\t" . $row->{"SwissProt_Description"} .
#            "\n\tOrganism\t" . $row->{"Organism"} .
#            "\n\tDomain\t" . $row->{"Domain"} .
#            "\n\tGN\t" . $row->{"GN"} .
#            "\n\tPFAM\t" . $row->{"PFAM"} .
#            "\n\tPDB\t" . $row->{"pdb"} .
#            "\n\tIPRO\t" . $row->{"IPRO"} .
#            "\n\tGO\t" . $row->{"GO"} .
#            "\n\tHMP_Body_Site\t" . $row->{"HMP_Body_Site"} .
#            "\n\tHMP_Oxygen\t" . $row->{"HMP_Oxygen"} .
#            "\n\tEC\t" . $row->{"EC"} .
#            "\n\tPHYLUM\t" . $row->{"Phylum"} .
#            "\n\tCLASS\t" . $row->{"Class"} .
#            "\n\tORDER\t" . $row->{"TaxOrder"} .
#            "\n\tFAMILY\t" . $row->{"Family"} .
#            "\n\tGENUS\t" . $row->{"Genus"} .
#            "\n\tSPECIES\t" . $row->{"Species"} .
#            "\n\tCAZY\t" . $row->{"Cazy"} .
#            "\n";

        push @accessions,$row->{"accessions"};
        $count++;
    }
    print "$taxid has $count matches\n";
}
close STRUCT;

open FASTA, ">$fasta" or die "Cannot write to output fasta $fasta\n";
while (scalar @accessions) {
    @batch = splice(@accessions, 0, $perpass);
    $batchline = join ',', @batch;
    @sequences = split /\n/, `fastacmd -d $data_files/combined.fasta -s $batchline`;
    foreach $sequence (@sequences) {
        $sequence =~ s/^>\w\w\|(\w{6,10})\|.*/>$1/;
        print FASTA "$sequence\n";
    }

}
close FASTA;

