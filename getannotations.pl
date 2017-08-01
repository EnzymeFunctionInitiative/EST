#!/usr/bin/env perl

#version 0.9.2 no changes to this file
#version 0.9.4 modifications due to removing sequence and classi fields and addition of uniprot_description field

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use DBD::SQLite;
use DBD::mysql;
use File::Slurp;
use FindBin;

use lib "$FindBin::Bin/lib";
use Biocluster::Database;
use Biocluster::Config;
use Annotations;



#$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
#eval $configfile;

my ($fasta, $annoOut, $metaFileIn, $configFile);
$result = GetOptions(
    "fasta=s"               => \$fasta,
    "out=s"                 => \$annoOut,
    "meta-file=s"           => \$metaFileIn,
    "config=s"              => \$configFile,
);

die "Command-line arguments are not valid: missing -config=config_file_path argument" if not defined $configFile or not -f $configFile;
die "Environment variables not set properly: missing EFIDB variable" if not exists $ENV{EFIDB};

print "Using $fasta as the input FASTA file\n";

@accessions=apply {chomp $_} apply {$_=~s/:\d+:\d+//} apply {$_=~s/^>//} `grep "\>" $fasta`;

my $db = new Biocluster::Database(config_file_path => $configFile);

open OUT, ">$annoOut" or die "cannot write struct.out file $annoOut\n";

my $dbh = $db->getHandle();

foreach $accession (@accessions){
    unless($accession=~/^z/){
        my $sql = Annotations::build_query_string($accession);
        #$sql = "select * from annotations as A join taxonomy as T on A.Taxonomy_ID = T.Taxonomy_ID where accession = '$accession'";
        print "SQL: $sql\n";
        $sth = $dbh->prepare($sql);
        $sth->execute;
        $row = $sth->fetchrow_hashref;
        
        print OUT Annotations::build_annotations($row);
        $sth->finish();
    }
}

$dbh->disconnect();

close OUT;

if($metaFileIn=~/\w+/ and -s $metaFileIn){
    #add user supplied dat info tio struct.out
    system("cat $metaFileIn >> $annoOut");
}

