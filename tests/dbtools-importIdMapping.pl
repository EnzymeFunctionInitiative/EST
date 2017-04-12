#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib/";
use lib "$FindBin::Bin/lib";
use Test::More;
use Biocluster::TestHelpers qw(writeTestConfig writeTestIdMapping);
use Biocluster::IdMappingBuilder;
use Biocluster::Config qw(biocluster_configure);
use Biocluster::Database;




my $cfgFile = "$FindBin::Bin/test.config";
writeTestConfig($cfgFile);

my $cfg = {};
biocluster_configure($cfg, config_file_path => $cfgFile);

my $db = new Biocluster::Database(config_file_path => "$FindBin::Bin/../efi.config", load_infile => 1);

my $buildDir = "build";
mkdir $buildDir if not -d $buildDir;
my $outputFile = "$buildDir/idmapping.tab";

my $mapper = new Biocluster::IdMappingBuilder(config_file_path => $cfgFile, build_dir => $buildDir);

my $resCode;
$resCode = $mapper->download(1);
isnt($resCode, -1, "Download overwrite");
is($resCode, 1, "Download success");

# This is for testing purposes
my $downloadedFile = "$buildDir/" . $mapper->getLocalFileName();
`gzip $downloadedFile`;

$resCode = $mapper->unzip($resCode);
is($resCode, 1, "gunzip success");

$resCode = $mapper->parse($outputFile, $resCode);
is($resCode, 1, "Parse success");


# Here we create a representative file that contains known values so we can compare the output
# to what is expected.
my $testInput = "$buildDir/test_idmapping.dat";
my $testOutput = "$buildDir/test_idmapping.tab";
writeTestIdMapping($testInput);
$resCode = $mapper->parse($testOutput, undef, $testInput);

ok(verifyParseTestIdMapping($testOutput));

done_testing(13);




sub verifyParseTestIdMapping {
    my ($testOutput) = @_;

    my $ok = 1;
    my $lineCount = 0;

    my @expected = (
        ["Q6GZX4", "49237298", "AAT09660.1", "YP_031579.1"],
        ["Q6GZX3", "", "AAT09661.1", ""]
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

    is($lineCount, 2, "Number of lines");

    return $ok;
}

exit;

my $mapTable = $db->{id_mapping_table};

if ($db->tableExists($mapTable)) {
    print "Table exists\n";
    print "Drop success: ", $db->dropTable($mapTable), "\n";
}

print "Create success: ", $db->createTable($map->getTableSchema()), "\n";


print "Does the table exist? ", $db->tableExists($mapTable), "\n";


print "Load success: ", $db->loadTabular($mapTable, "$FindBin::Bin/build/test_idmapping.tab");
#my $loadSql = $db->getLoadTabularSql($mapTable, "$FindBin::Bin/build/test_idmapping.tab");
#
#print <<ML;
#The database is now ready for the data load.  Start MySQL as follows:
#
#  mysql -p -h $db->{db_host} -P $db->{db_port} $db->{db_name}
#
#Then execute the following statement:
#
#  $loadSql;
#
#ML
#;


