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
use EFI::Annotations;

use lib "$FindBin::Bin/lib";

use EST::Setup;
use EST::Family;


my ($inputConfig, $dbh, $configFile, $seqObj, $accObj, $metaObj, $statsObj) = setupConfig();

if (not exists $inputConfig->{data}) {
    print "ERROR: No family provided.\n";
    exit(1);
}

$metaObj->configureSourceTypes(
    EFI::Annotations::FIELD_SEQ_SRC_VALUE_FAMILY,
);
$statsObj->configureSourceTypes(
    EFI::Annotations::FIELD_SEQ_SRC_VALUE_FAMILY,
);


my $famData = new EST::Family(dbh => $dbh, db_version => $inputConfig->{db_version});
$famData->configure($inputConfig);

$famData->retrieveFamilyAccessions();

my $familyIds = $famData->getSequenceIds();
my $familyMetadata = $famData->getMetadata();
my $familyStats = $famData->getStatistics();
my $userIds = {};
my $userMetadata = {};
my $unirefMap = $famData->getUniRefMapping();
my $familyFullDomainIds = $famData->getFullFamilyDomain();


$seqObj->retrieveAndSaveSequences($familyIds); # file path is configured by setupConfig
$accObj->saveSequenceIds($familyIds); # file path is configured by setupConfig
my $mergedMetadata = $metaObj->saveSequenceMetadata($familyMetadata, $userMetadata, $unirefMap);
$statsObj->saveSequenceStatistics($mergedMetadata, {}, $familyStats, {});
$famData->saveSunburstIdsToFile($inputConfig->{config}->{sunburst_output_file});

if ($inputConfig->{uniprot_domain_length_file}) {
    my $histo = new EST::LengthHistogram;
    $histo->addData($familyFullDomainIds);
    $histo->saveToFile($inputConfig->{uniprot_domain_length_file});
}

