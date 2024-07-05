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


my $outputFile = "$buildDir/idmapping.tab";

my $mapper = new Biocluster::IdMapping::Builder(config_file_path => $cfgFile, build_dir => $buildDir);

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


done_testing(4);


