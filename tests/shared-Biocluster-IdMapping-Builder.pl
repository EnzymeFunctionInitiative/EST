#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib/";
use lib "$FindBin::Bin/lib";
use Test::More;
use Biocluster::TestHelpers qw(writeTestConfig writeTestIdMapping saveIdMappingTable);
use Biocluster::IdMapping::Builder;
use Biocluster::Config qw(biocluster_configure);
use Biocluster::Database;


our ($mapBuilder, $cfgFile, $cfg, $db, $buildDir);
do "initializeTest.pl";

#######################################################################################################################
# SET UP THE TEST
#

saveIdMappingTable($db, $cfgFile, $buildDir);

#my $testInput = "$buildDir/test_idmapping.dat";
#my $testOutput = "$buildDir/test_idmapping.tab";
#writeTestIdMapping($testInput);
#$mapBuilder = new Biocluster::IdMapping::Builder(config_file_path => $cfgFile, build_dir => $buildDir);
#my $resCode = $mapBuilder->parse($testOutput, undef, $testInput);
#my $mapTable = $db->{id_mapping}->{table};
#$db->dropTable($mapTable) if ($db->tableExists($mapTable));
#$db->createTable($mapBuilder->getTableSchema());
#$db->tableExists($mapTable);
#$db->loadTabular($mapTable, "$FindBin::Bin/build/test_idmapping.tab");


