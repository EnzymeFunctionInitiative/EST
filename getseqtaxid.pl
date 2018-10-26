#!/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

#version 0.9.2 no changes to this file
#version 0.9.5 fixed a bug in creating struct.out file where not all annotation information was being written

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use DBD::SQLite;
use DBD::mysql;
use File::Slurp;
use FindBin;
use EFI::Database;
use EFI::Annotations;

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

my $db = new EFI::Database(config_file_path => $configFile);
my $dbh = $db->getHandle();


open(STRUCT, ">$struct") or die "could not create struct file $struct\n";
print "database $ENV{EFIDB}\n";

my @accessions = ();
my $perpass = $ENV{EFIPASS};
my @taxids = split /,/, $taxid;

foreach my $taxid (@taxids){
    print "getting resuts for $taxid\n";
    my $count = 0;

    my $sql = EFI::Annotations::build_taxid_query_string($taxid);
    #$sql = "select * from annotations where Taxonomy_ID = '$taxid'";
    my $sth = $dbh->prepare($sql);

    $sth->execute;
    while ($row = $sth->fetchrow_hashref) {
        print STRUCT EFI::Annotations::build_annotations($row->{accession}, $row);
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

