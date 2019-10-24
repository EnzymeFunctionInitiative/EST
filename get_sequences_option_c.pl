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
use EST::FASTA;


my ($familyConfig, $dbh, $configFile, $seqObj, $accObj, $metaObj, $statsObj) = setupConfig();

$metaObj->configureSourceTypes(
    EFI::Annotations::FIELD_SEQ_SRC_VALUE_FAMILY,
    EFI::Annotations::FIELD_SEQ_SRC_VALUE_FASTA,
    EFI::Annotations::FIELD_SEQ_SRC_VALUE_BOTH,
);
$statsObj->configureSourceTypes(
    EFI::Annotations::FIELD_SEQ_SRC_VALUE_FAMILY,
    EFI::Annotations::FIELD_SEQ_SRC_VALUE_FASTA,
    EFI::Annotations::FIELD_SEQ_SRC_VALUE_BOTH,
);

my $familyIds = {};
my $familyMetadata = {};
my $familyStats = {};
my $unirefMap = {};

if (exists $familyConfig->{data}) {
    my $famData = new EST::Family(dbh => $dbh);
    $famData->configure($familyConfig);
    $famData->retrieveFamilyAccessions();
    $familyIds = $famData->getSequenceIds();
    $familyMetadata = $famData->getMetadata();
    $familyStats = $famData->getStatistics();
    $unirefMap = $famData->getUniRefMapping();
}


my %fastaArgs = EST::FASTA::getFastaCmdLineArgs();
my $fastaData = new EST::FASTA(config_file_path => $configFile);
$fastaData->configure(%fastaArgs);
$fastaData->parseFile();


my $userIds = $fastaData->getSequenceIds();
my $userMetadata = $fastaData->getMetadata();
my $userStats = $fastaData->getStatistics();
my $userSeq = $fastaData->getUnmatchedSequences();

$seqObj->retrieveAndSaveSequences($familyIds, $userIds, $userSeq, $unirefMap); # file path is configured by setupConfig
$accObj->saveSequenceIds($familyIds, $userIds, $unirefMap); # file path is configured by setupConfig
my $mergedMetadata = $metaObj->saveSequenceMetadata($familyMetadata, $userMetadata, $unirefMap);
$statsObj->saveSequenceStatistics($mergedMetadata, $userMetadata, $familyStats, $userStats);

