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

if (exists $familyConfig->{data}) {
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

my $inputIdSource = {};
$inputIdSource->{$EST::BLAST::INPUT_SEQ_ID} = $EST::BLAST::INPUT_SEQ_TYPE;


#map { print "B\t$_\n"; } keys %$userIds;
#map { print "F\t$_\n"; } keys %$familyIds;
$seqObj->retrieveAndSaveSequences($familyIds, $userIds, $userSeq, $unirefMap); # file path is configured by setupConfig
$accObj->saveSequenceIds($familyIds, $userIds, $unirefMap); # file path is configured by setupConfig
my $mergedMetadata = $metaObj->saveSequenceMetadata($familyMetadata, $userMetadata, $unirefMap, $inputIdSource);
$statsObj->saveSequenceStatistics($mergedMetadata, $userMetadata, $familyStats, $userStats);

