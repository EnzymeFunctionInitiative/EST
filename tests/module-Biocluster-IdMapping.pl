#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib/";
use lib "$FindBin::Bin/lib";
use Test::More;
use Biocluster::TestHelpers qw(writeTestConfig writeTestIdMapping);
use Biocluster::IdMapping;
use Biocluster::IdMapping::Builder;
use Biocluster::IdMapping::Util;
use Biocluster::Config qw(biocluster_configure);
use Biocluster::Database;


our ($cfgFile);
do "shared-Biocluster-IdMapping-Builder.pl";


#######################################################################################################################
# RUN TEST FOR RETRIEVING MAPPING
#

my $mapper = new Biocluster::IdMapping(config_file_path => $cfgFile);
my @ncbiIds = ("fail1", "YP_031579.1", "fail2");

my ($uniprotIds, $noMatches) = $mapper->reverseLookup(NCBI, @ncbiIds);

is($#$uniprotIds, 0, "Number of matches");
is($uniprotIds->[0], "Q6GZX4", "The matched item");
is($#$noMatches, 1, "Number of no matches");

done_testing(3);



