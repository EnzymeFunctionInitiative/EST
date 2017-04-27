#!perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Biocluster::IdMapping::Builder;
use Getopt::Long;


my ($cfgFile, $buildDir);
GetOptions("config=s", \$cfgFile);

die "--config=file_path option must be provided" unless (defined $cfgFile and -f $cfgFile);

my $mapBuilder = new Biocluster::IdMapping::Builder(config_file_path => $cfgFile, build_dir => "none");
my $schema = $mapBuilder->getTableSchema();

print $schema->getCreateSql();

print "\n\n\n";

