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
use EST::Accession;


my ($familyConfig, $dbh, $configFile, $seqObj, $accObj, $metaObj, $statsObj) = setupConfig();

$metaObj->configureSourceTypes(
    EFI::Annotations::FIELD_SEQ_SRC_VALUE_FAMILY,
    EFI::Annotations::FIELD_SEQ_SRC_VALUE_BLASTHIT,
    EFI::Annotations::FIELD_SEQ_SRC_VALUE_BLASTHIT_FAMILY,
);
$statsObj->configureSourceTypes(
    EFI::Annotations::FIELD_SEQ_SRC_VALUE_FAMILY,
    EFI::Annotations::FIELD_SEQ_SRC_VALUE_BLASTHIT,
    EFI::Annotations::FIELD_SEQ_SRC_VALUE_BLASTHIT_FAMILY,
);

my $familyIds = {};
my $familyMetadata = {};
my $familyStats = {};
my $unirefMap = {};

if ($familyConfig) {
    my $famData = new EST::Family(dbh => $dbh);
    $famData->configure($familyConfig);
    $famData->retrieveFamilyAccessions();
    $familyIds = $famData->getSequenceIds();
    $familyMetadata = $famData->getMetadata();
    $familyStats = $famData->getStatistics();
    $unirefMap = $famData->getUniRefMapping();
}


my %accessionArgs = getAccessionCmdLineArgs();
my $accessionData = new EST::Accession(dbh => $dbh, config_file_path => $configFile);
$accessionData->configure(%accessionArgs);
$accessionData->parseFile();


my $userIds = $accessionData->getSequenceIds();
my $userMetadata = $accessionData->getMetadata();
my $userStats = $accessionData->getStatistics();

$seqObj->retrieveAndSaveSequences($familyIds, $userIds); # file path is configured by setupConfig
$accObj->saveSequenceIds($familyIds, $userIds); # file path is configured by setupConfig
my $metadata = $metaObj->saveSequenceMetadata($familyMetadata, $userMetadata, $unirefMap);
$statsObj->saveSequenceStatistics($metadata, $familyStats, $userStats);

