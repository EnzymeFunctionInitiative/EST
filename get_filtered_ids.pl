#!/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}


use strict;
use warnings;


use Getopt::Long;
use FindBin;
use Data::Dumper;

use lib "$FindBin::Bin/lib";

use EFI::Database;
use EST::Filter qw(parse_tax_search flatten_tax_search exclude_ids);
use FileUtil;



my ($inputFile, $outputFile, $outputIdList, $configFile, $taxFilter, $removeFragments);
my $result = GetOptions(
    "meta-file=s"           => \$inputFile,
    "filtered-meta-file=s"  => \$outputFile,
    "config=s"              => \$configFile,
    "tax-filter=s"          => \$taxFilter,
    "remove-fragments"      => \$removeFragments,
    "filter-id-list=s"      => \$outputIdList,
);


die "Require --tax-search or --remove-fragments" if (not $taxFilter and not $removeFragments);
die "Require --filtered-meta-file output" if not $outputFile;
die "Require --meta-file input file" if not $inputFile or not -f $inputFile;

if (not $configFile) {
    if (not exists $ENV{EFI_CONFIG}) {
        die "Missing configuration variable EFI_CONFIG or -config argument.";
    } else {
        $configFile = $ENV{EFI_CONFIG};
        if (not -f $configFile) {
            die "Missing configuration variable EFI_CONFIG or -config argument.";
        }
    }
}



my $db = new EFI::Database(config_file_path => $configFile);
my $dbh = $db->getHandle();


my $taxData = 0;
$taxData = parse_tax_search($taxFilter) if $taxData;

my ($meta, $origIdOrder) = FileUtil::read_struct_file($inputFile); # Hashref of IDs to metadata

my $uniref50Key = "UniRef50_IDs";
my $uniref90Key = "UniRef90_IDs";
my $unirefKey = "";
my $unirefVersion = 0;

my $ids = {};
foreach my $id (keys %$meta) {
    $ids->{$id} = {};
    if ($meta->{$id}->{$uniref50Key} or $meta->{$id}->{$uniref90Key}) {
        if (not $unirefKey) {
            if ($meta->{$id}->{$uniref90Key}) {
                $unirefKey = $uniref90Key;
                $unirefVersion = 90;
            } else {
                $unirefKey = $uniref50Key;
                $unirefVersion = 50;
            }
        }

        my @ids = split(m/,/, $meta->{$id}->{$unirefKey});
        $ids->{$id}->{$unirefKey} = \@ids;
    }
}


my $filterFragments = $removeFragments ? 1 : 0;
my $familyFilter = 0;
my ($idsToUse, $unirefMapping) = exclude_ids($dbh, $filterFragments, $ids, $taxData, $unirefVersion, $familyFilter);


my $newMeta = {};

if ($unirefKey) {
    $unirefMapping = $unirefMapping->{$unirefVersion};
    # $idsToUse contains UniRef IDs
    foreach my $id (keys %$idsToUse) {
        # These are the UniProt IDs in the UniRef cluster that matched the filter
        my %uniprotIds = map { $_ => 1 } @{ $unirefMapping->{$id} };
        # Only include IDs in the metadata attribute that match the filter
        my @newIds = grep { exists $uniprotIds{$_} } @{ $idsToUse->{$id}->{$unirefKey} };
        $newMeta->{$id} = $meta->{$id};
        $newMeta->{$id}->{$unirefKey} = join(",", @newIds);
        #$idsToUse->{$id}->{$unirefKey} = \@newIds;
    }
} else {
    foreach my $id (keys %$idsToUse) {
        $newMeta->{$id} = $meta->{$id};
    }
}



FileUtil::write_struct_file($newMeta, $outputFile, $origIdOrder);


open my $fh, ">", $outputIdList or die "Unable to write to id list file $outputIdList: $!";

foreach my $id (sort keys %$newMeta) {
    $fh->print("$id\n");
}

close $fh;


