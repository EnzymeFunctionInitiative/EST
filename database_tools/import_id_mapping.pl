#!/usr/bin/perl -w

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

use strict;
use FindBin;
use EFI::IdMapping::Builder;
use EFI::Database;
use Getopt::Long;

my ($configFile, $buildDir, $idMappingFile, $outputFile, $loadDb);
GetOptions(
    "config=s"      => \$configFile,
    "build=s"       => \$buildDir,
    "input=s"       => \$idMappingFile,
    "output=s"      => \$outputFile,
    "load-db"       => \$loadDb,
);


if (not defined $configFile or not -f $configFile) {
    if (exists $ENV{EFICONFIG}) {
        $configFile = $ENV{EFICONFIG};
    } else {
        die "--config file parameter is not specified.  module load efiest_v2 should take care of this.";
    }
}

die "--input=id_mapping.dat input file must be provided" unless (defined $idMappingFile and -f $idMappingFile);
die "--output=output_tab_file must be provided" unless defined $outputFile;

$buildDir = "" if not defined $buildDir;
my $mapBuilder = new EFI::IdMapping::Builder(config_file_path => $configFile, build_dir => $buildDir);

my $resCode = $mapBuilder->parse($outputFile, undef, $idMappingFile, 1);

if (defined $loadDb) {
    my $db = new EFI::Database(config_file_path => $configFile);
    my $mapTable = $db->{id_mapping}->{table};
    $db->dropTable($mapTable) if ($db->tableExists($mapTable));
    $db->createTable($mapBuilder->getTableSchema());
    $db->tableExists($mapTable);
    $db->loadTabular($mapTable, $outputFile);
}


