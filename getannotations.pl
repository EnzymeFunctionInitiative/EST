#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

#version 0.9.2 no changes to this file
#version 0.9.4 modifications due to removing sequence and classi fields and addition of uniprot_description field

use strict;
use warnings;

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use FindBin;

use EFI::Database;
use EFI::Config;
use EFI::Annotations;
use EFI::IdMapping::Util;



my ($fasta, $annoOut, $metaFileIn, $unirefVersion, $configFile);
my $result = GetOptions(
    "fasta=s"               => \$fasta,
    "out=s"                 => \$annoOut,
    "meta-file=s"           => \$metaFileIn,
    "uniref-version=s"      => \$unirefVersion,
    "config=s"              => \$configFile,
);

die "Command-line arguments are not valid: missing -config=config_file_path argument" if not defined $configFile or not -f $configFile;
die "Environment variables not set properly: missing EFIDB variable" if not exists $ENV{EFIDB};

$unirefVersion = "" if not defined $unirefVersion or ($unirefVersion ne "90" and $unirefVersion ne "50");

print "Using $fasta as the input FASTA file\n";

my %idTypes;
$idTypes{EFI::IdMapping::Util::GENBANK} = uc EFI::IdMapping::Util::GENBANK;
$idTypes{EFI::IdMapping::Util::GI} = uc EFI::IdMapping::Util::GI;
$idTypes{EFI::IdMapping::Util::NCBI} = uc EFI::IdMapping::Util::NCBI;

my @accessions = apply {chomp $_} apply {$_=~s/:\d+:\d+//} apply {$_=~s/^>//} `grep "\>" $fasta`;

my $db = new EFI::Database(config_file_path => $configFile);

open OUT, ">$annoOut" or die "cannot write struct.out file $annoOut\n";

my $dbh = $db->getHandle();

foreach my $accession (@accessions){
    if ($accession !~ /^z/) {

        # If we are using UniRef, we need to get the attributes for all of the IDs in the UniRef seed
        # sequence cluster.  This code does that.
        my $sql = "";
        if ($unirefVersion) {
            my @idList; # = ($accession);

            my $idSql = EFI::Annotations::build_uniref_id_query_string($accession, $unirefVersion);
            my $sth = $dbh->prepare($idSql);
            $sth->execute;
            while (my $row = $sth->fetchrow_hashref) {
                push @idList, $row->{ID};
            }
            $sth->finish;

            @idList = $accession if not scalar @idList;

            $sql = EFI::Annotations::build_query_string(\@idList);
        } else {
            $sql = EFI::Annotations::build_query_string($accession);
        }

        #$sql = "select * from annotations as A join taxonomy as T on A.Taxonomy_ID = T.Taxonomy_ID where accession = '$accession'";
        my $sth = $dbh->prepare($sql);
        $sth->execute;
        my @rows;
        while (my $row = $sth->fetchrow_hashref) {
            push @rows, $row;
        }
        $sth->finish;
 #TODO: handle uniref cluster seqeuences ncbi ids
        # Now get a list of NCBI IDs
        $sql = EFI::Annotations::build_id_mapping_query_string($accession);
        $sth = $dbh->prepare($sql);
        $sth->execute;
        my @ncbiIds;
        while (my $idRow = $sth->fetchrow_hashref) {
            if (exists $idTypes{$idRow->{foreign_id_type}}) {
                push @ncbiIds, $idTypes{$idRow->{foreign_id_type}} . ":" . $idRow->{foreign_id};
            }
        }
        
        my $data = EFI::Annotations::build_annotations($accession, \@rows, \@ncbiIds);
        print OUT $data;
        $sth->finish();
    }
}

$dbh->disconnect();


close OUT;

if($metaFileIn=~/\w+/ and -s $metaFileIn){
    #add user supplied dat info tio struct.out
    system("cat $metaFileIn >> $annoOut");
}

