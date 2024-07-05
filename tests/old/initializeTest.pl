#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib/";
use lib "$FindBin::Bin/lib";
use Test::More;
use Biocluster::TestHelpers qw(writeTestConfig writeTestIdMapping);
use Biocluster::IdMapping;
use Biocluster::Config qw(biocluster_configure);
use Biocluster::Database;


our $cfgFile = "$FindBin::Bin/test.config";
writeTestConfig($cfgFile);

our $cfg = {};
biocluster_configure($cfg, config_file_path => $cfgFile);


our $db = new Biocluster::Database(config_file_path => $cfgFile, load_infile => 1);

our $buildDir = "build";
mkdir $buildDir if not -d $buildDir;


