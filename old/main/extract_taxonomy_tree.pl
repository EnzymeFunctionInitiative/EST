#!/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}

use strict;
use warnings;

use FindBin;
use Getopt::Long;
use Data::Dumper;

use Taxonomy::Tree;


my ($jsonFile, $treeId, $idType, $outputFile);
my $result = GetOptions(
    "--json-file=s"         => \$jsonFile,
    "--tree-id=s"           => \$treeId,
    "--id-type=s"           => \$idType,
    "--output-file=s"       => \$outputFile,
);


die "Need --json-file" if not $jsonFile or not -f $jsonFile;
die "Need --tree-id" if not defined $treeId;
die "Need --id-type" if not $idType;
die "Need --output-file" if not $outputFile;


my $taxo = new Taxonomy::Tree;


if (not $taxo->load($jsonFile)) {
    print STDERR "There was a problem loading the json file $jsonFile\n";
    exit(1);
}


my $tree = $taxo->getSubTree($treeId);

my $ids = $taxo->getIdsFromTree($tree, $idType);

open my $fh, ">", $outputFile;

map { $fh->print("$_\n"); } @$ids;

close $fh;

