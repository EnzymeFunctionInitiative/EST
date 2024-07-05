#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib/";
use lib "$FindBin::Bin/lib";
use Test::More;
use Biocluster::TestHelpers qw(writeTestConfig writeTestIdMapping);
use Biocluster::IdMapping::Builder;
use Biocluster::Config qw(biocluster_configure);
use Biocluster::Database;


our ($cfgFile, $cfg, $db, $buildDir);
do "initializeTest.pl";


print "$cfgFile\n";
my $mapBuilder = new Biocluster::IdMapping::Builder(config_file_path => $cfgFile, build_dir => $buildDir);

print "POST INIT\n";

#######################################################################################################################
# TEST PARSE LOCAL FILE
#

my $testInput = "$buildDir/test_idmapping.dat";
my $testOutput = "$buildDir/test_idmapping.tab";
writeTestIdMapping($testInput);
my $resCode = $mapBuilder->parse($testOutput, undef, $testInput);

ok(verifyParseTestIdMapping($testOutput));

my $numTests = 17;

#######################################################################################################################
# TEST ADDING THE TABLE TO THE DATABASE
#
my $mapTable = $db->{id_mapping}->{table};

if ($db->tableExists($mapTable)) {
    $numTests++;
    ok($db->dropTable($mapTable), "Drop $mapTable");
}
print $mapBuilder->getTableSchema()->getCreateSql(), "\n\n";
ok($db->createTable($mapBuilder->getTableSchema()), "Create $mapTable");
ok($db->tableExists($mapTable), "$mapTable exists");
ok($db->loadTabular($mapTable, "$FindBin::Bin/build/test_idmapping.tab"), "Tabular data load into $mapTable");

$numTests += 3;
done_testing($numTests);




sub verifyParseTestIdMapping {
    my ($testOutput) = @_;

    my $ok = 1;
    my $lineCount = 0;

    my @expected = (
        ["Q6GZX4", "gi", "81941549"],
        ["Q6GZX4", "gi", "49237298"],
        ["Q6GZX4", "embl-cds", "AAT09660.1"],
        ["Q6GZX4", "refseq", "YP_031579.1"],
        ["Q6GZX3", "embl-cds", "AAT09661.1"],
        ["Q6GZX3", "pdb", "1DTN"],
    );

    open TAB, $testOutput;
    while (<TAB>) {
        chomp;

        my @parts = split m/\t/;
        for (my $i = 0; $i <= $#parts; $i++) {
            is($parts[$i], $expected[$lineCount][$i], "output tab file line=$lineCount, col=$i");
        }
        $lineCount++;
    }
    close TAB;

    is($lineCount + 1, 6, "Number of lines");

    return $ok;
}


