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
my ($outputFile, $expandUniref);
my $result = GetOptions(
    "struct=s"              => \$annoFile,
    "config=s"              => \$configFile,
    "incfrac=f"             => \$incfrac,
    "output=s"              => \$outputFile,
    "expand-uniref"         => \$expandUniref,
);


die "Requires input -struct argument for annotation IDs" if not $annoFile or not -f $annoFile;
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
my $annoMap = FileUtil::read_struct_file($annoFile);
my @metaIds = grep m/^[^z]/, keys %$annoMap;
my @unkIds = grep m/^z/, keys %$annoMap; # unknown IDs (e.g. zzz*)

if ($expandUniref) {
    my @uniprotIds;
    foreach my $clId (@metaIds) {
        my $ids = exists $annoMap->{$clId}->{UniRef90_IDs} ? $annoMap->{$clId}->{UniRef90_IDs} :
                  exists $annoMap->{$clId}->{UniRef50_IDs} ? $annoMap->{$clId}->{UniRef50_IDs} : "";
        my @ids = split(m/,/, $ids);
        push @uniprotIds, @ids;
        push @uniprotIds, $clId if not scalar @ids;
    }
    @metaIds = @uniprotIds;
}


my $histo = new EST::LengthHistogram(incfrac => $incfrac);

while (@metaIds) {
    my @batch = splice(@metaIds, 0, 50);
    my $queryIds = join("','", @batch);
    my $sql = "SELECT accession, Sequence_Length FROM annotations WHERE accession IN ('$queryIds')";
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    while (my $row = $sth->fetchrow_arrayref) {
        my $len = $row->[1];
        $histo->addData($len);
    }
}

foreach my $id (@unkIds) {
    my $len = $annoMap->{$id}->{Sequence_Length};
    $histo->addData($len);
}


$histo->saveToFile($outputFile);


