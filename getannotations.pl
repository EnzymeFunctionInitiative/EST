#!/usr/bin/env perl

#version 0.9.2 no changes to this file
#version 0.9.4 modifications due to removing sequence and classi fields and addition of uniprot_description field

use strict;

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use FindBin;

use lib "$FindBin::Bin/lib";
use Biocluster::Database;
use Biocluster::Config;
use Annotations;
use Biocluster::IdMapping::Util;



my ($fasta, $annoOut, $metaFileIn, $configFile);
my $result = GetOptions(
    "fasta=s"               => \$fasta,
    "out=s"                 => \$annoOut,
    "meta-file=s"           => \$metaFileIn,
    "config=s"              => \$configFile,
);

die "Command-line arguments are not valid: missing -config=config_file_path argument" if not defined $configFile or not -f $configFile;
die "Environment variables not set properly: missing EFIDB variable" if not exists $ENV{EFIDB};

print "Using $fasta as the input FASTA file\n";

my %idTypes;
$idTypes{Biocluster::IdMapping::Util::GENBANK} = uc Biocluster::IdMapping::Util::GENBANK;
$idTypes{Biocluster::IdMapping::Util::GI} = uc Biocluster::IdMapping::Util::GI;
$idTypes{Biocluster::IdMapping::Util::NCBI} = uc Biocluster::IdMapping::Util::NCBI;

my @accessions = apply {chomp $_} apply {$_=~s/:\d+:\d+//} apply {$_=~s/^>//} `grep "\>" $fasta`;

my $db = new Biocluster::Database(config_file_path => $configFile);

open OUT, ">$annoOut" or die "cannot write struct.out file $annoOut\n";

my $dbh = $db->getHandle();

foreach my $accession (@accessions){
    unless($accession=~/^z/){
        my $sql = Annotations::build_query_string($accession);
        #$sql = "select * from annotations as A join taxonomy as T on A.Taxonomy_ID = T.Taxonomy_ID where accession = '$accession'";
        my $sth = $dbh->prepare($sql);
        $sth->execute;
        my $row = $sth->fetchrow_hashref;
        $sth->finish;

        # Now get a list of NCBI IDs
        $sql = Annotations::build_id_mapping_query_string($accession);
        $sth = $dbh->prepare($sql);
        $sth->execute;
        my @ncbiIds;
        while (my $idRow = $sth->fetchrow_hashref) {
            if (exists $idTypes{$idRow->{foreign_id_type}}) {
                push @ncbiIds, $idTypes{$idRow->{foreign_id_type}} . ":" . $idRow->{foreign_id};
            }
        }
        
        print OUT Annotations::build_annotations($row, \@ncbiIds);
        $sth->finish();
    }
}

$dbh->disconnect();

close OUT;

if($metaFileIn=~/\w+/ and -s $metaFileIn){
    #add user supplied dat info tio struct.out
    system("cat $metaFileIn >> $annoOut");
}

