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

our ($mapBuilder);
do "shared-Biocluster-IdMapping-Builder.pl";


#######################################################################################################################
# TEST
# 

my @keys = $mapBuilder->getMapKeysSorted();

is($#keys, 2, "Number of keys");

done_testing(1);

