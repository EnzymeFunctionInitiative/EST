#!/usr/bin/env perl

# This script reads the annotation file (struct.out) and outputs a file containing data
# for a length histograph for ALL sequences, not just UniRef seed sequences.

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}


use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/lib";

use FileUtil;
use EFI::Database;
use EST::LengthHistogram;



my ($annoFile, $configFile, $incfrac);
my ($outputFile, $expandUniref, $outputUniref50, $outputUniref90);
my $result = GetOptions(
    "struct=s"              => \$annoFile,
    "config=s"              => \$configFile,
    "incfrac=f"             => \$incfrac,
    "output=s"              => \$outputFile,
    "expand-uniref"         => \$expandUniref,
    "output-uniref90-len=s" => \$outputUniref90,
    "output-uniref50-len=s" => \$outputUniref50,
);


die "Requires input --struct argument for annotation IDs" if not $annoFile or not -f $annoFile;
die "Requires output length file argument" if not $outputFile;


if (not defined $configFile or not -f $configFile) {
    if (exists $ENV{EFI_CONFIG}) {
        $configFile = $ENV{EFI_CONFIG};
    } else {
        die "--config file parameter is not specified";
    }
}

$incfrac = 0.99 if not defined $incfrac or $incfrac !~ m/^[\.\d]+$/;


my $db = new EFI::Database(config_file_path => $configFile);
my $dbh = $db->getHandle();


# Contains the attributes for each UniRef cluster ID
my ($annoMap) = FileUtil::read_struct_file($annoFile);
my @metaIds = grep m/^[^z]/, keys %$annoMap;
my @unkIds = grep m/^z/, keys %$annoMap; # unknown IDs (e.g. zzz*)

my @seedIds;
my @uniprotIds;
if ($expandUniref and not $outputUniref90) {
    foreach my $clId (@metaIds) {
        my $ids = exists $annoMap->{$clId}->{UniRef90_IDs} ? $annoMap->{$clId}->{UniRef90_IDs} :
                  exists $annoMap->{$clId}->{UniRef50_IDs} ? $annoMap->{$clId}->{UniRef50_IDs} : "";
        my @ids = split(m/,/, $ids);
        push @uniprotIds, @ids;
        push @seedIds, $clId;
    }
} else {
    @uniprotIds = @metaIds;
}



my $histo = new EST::LengthHistogram(incfrac => $incfrac);
my $histoUniref50 = new EST::LengthHistogram(incfrac => $incfrac);
my $histoUniref90 = new EST::LengthHistogram(incfrac => $incfrac);

my $seqLenField = "seq_len";

my $allUnirefField = "";
my $allUnirefJoin = "";
my $whereField = "A.accession";
if ($outputUniref90) {
    $allUnirefField = ", U.uniref50_seed, U.uniref90_seed";
    $allUnirefJoin = "LEFT JOIN uniref AS U ON A.accession = U.accession";
    $whereField = "U.accession";
}


my %histoHasUniref90;
my %histoHasUniref50;

while (@uniprotIds) {
    my @batch = splice(@uniprotIds, 0, 50);
    my $queryIds = join("','", @batch);
    my $sql = "SELECT $whereField AS acc, $seqLenField $allUnirefField FROM annotations AS A $allUnirefJoin WHERE $whereField IN ('$queryIds')";
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    while (my $row = $sth->fetchrow_hashref) {
        my $len = $row->{seq_len};
        $histo->addData($len);
        if ($row->{uniref50_seed}) {
            $histoUniref50->addData($len) if not $histoHasUniref50{$row->{uniref50_seed}};
            $histoHasUniref50{$row->{uniref50_seed}} = 1;
        }
        if ($row->{uniref90_seed}) {
            $histoUniref90->addData($len) if not $histoHasUniref90{$row->{uniref90_seed}};
            $histoHasUniref90{$row->{uniref90_seed}} = 1;
        }
    }
}

foreach my $id (@unkIds) {
    my $len = $annoMap->{$id}->{$seqLenField};
    $histo->addData($len);
}


$histo->saveToFile($outputFile) if $outputFile;
$histoUniref50->saveToFile($outputUniref50) if $outputUniref50;
$histoUniref90->saveToFile($outputUniref90) if $outputUniref90;


