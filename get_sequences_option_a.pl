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
use EST::BLAST;


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

if ($familyConfig) {
    my $famData = new EST::Family(dbh => $dbh);
    $famData->configure($familyConfig);
    $famData->retrieveFamilyAccessions();
    $familyIds = $famData->getSequenceIds();
    $familyMetadata = $famData->getMetadata();
    $familyStats = $famData->getStatistics();
    $unirefMap = $famData->getUniRefMapping();
}


my %blastArgs = getBLASTCmdLineArgs();
my $blastData = new EST::BLAST();
$blastData->configure(%blastArgs);
$blastData->parseFile();


my $userIds = $blastData->getSequenceIds();
my $userMetadata = $blastData->getMetadata();
my $userStats = $blastData->getStatistics();
my $userSeq = $blastData->getQuerySequence();


$seqObj->retrieveAndSaveSequences($familyIds, $userIds, $userSeq); # file path is configured by setupConfig
$accObj->saveSequenceIds($familyIds, $userIds); # file path is configured by setupConfig
my $metadata = $metaObj->saveSequenceMetadata($familyMetadata, $userMetadata, $unirefMap);
$statsObj->saveSequenceStatistics($metadata, $familyStats, $userStats);

