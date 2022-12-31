#!/usr/bin/env perl

BEGIN {
    die "The efishared and efignt environments must be loaded before running this script" if not exists $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}

use strict;
use warnings;

use Getopt::Long;
use Getopt::Long qw(:config pass_through);
use FindBin;
use File::Basename;
use lib $FindBin::Bin . "/lib";

use EFI::SchedulerApi;
use EFI::Util qw(usesSlurm);


my $estPath = $FindBin::Bin;

my ($ssnIn, $baseDir, $outputName, $resultsDirName);
my ($scheduler, $dryRun, $queue, $jobId, $configFile, $ramReservation, $dumpOnly);
my $result = GetOptions(
    "ssn-in=s"                  => \$ssnIn,
    "output-name=s"             => \$outputName,
    "output-path=s"             => \$baseDir, # top-level job directory
    "out-dir=s"                 => \$resultsDirName, # name of results sub-dir (e.g. output)
    "dump-only"                 => \$dumpOnly,
    "scheduler=s"               => \$scheduler,
    "dry-run"                   => \$dryRun,
    "queue=s"                   => \$queue,
    "job-id=s"                  => \$jobId,
    "ram=i"                     => \$ramReservation,
    "config=s"                  => \$configFile,
);

my $usage = <<USAGE
usage: $0 -ssnin <filename>

    --ssn-in            path to file of original ssn network to process
    --output-path       output directory
    --output-name       name of output file
    --scheduler         scheduler type (default to torque, but also can be slurm)
    --dry-run           only generate the scripts, don't submit to queue
    --queue             the cluster queue to use

The only required argument is --ssn-in, all others have defaults.
USAGE
;


my $extraPerl = "$ENV{EFI_PERL_ENV}";


$baseDir = $ENV{PWD} if not $baseDir;
my $outputPath = "$baseDir/$resultsDirName";
mkdir $outputPath;

$queue = $ENV{EFI_QUEUE} if not $queue;
$configFile = $ENV{EFI_CONFIG} if not $configFile or not -f $configFile;
if (not $configFile or not -f $configFile) {
    die "Either the configuration file or the EFI_CONFIG environment variable must be set\n$usage";
}
my $estModule = $ENV{EFI_EST_MOD};

$ssnIn = "$ENV{PWD}/$ssnIn" if $ssnIn and $ssnIn !~ m/^\//;
if (not $ssnIn or not -s $ssnIn) {
    $ssnIn = "" if not $ssnIn;
    die "--ssn-in $ssnIn does not exist or has a zero size\n$usage";
}

die "$usage\nERROR: missing --queue parameter" if not $queue;

my $schedType = "torque";
$schedType = "slurm" if (defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm());


($outputName = $ssnIn) =~ s%.*?([^/]+)\.xgmml$%$1% if not $outputName;
$outputName =~ s/[^a-zA-Z0-9\-_,\.]/_/g;

my $ssnInZip = $ssnIn;
if ($ssnInZip =~ /\.zip$/i) {
    my ($fn, $fp, $fx) = fileparse($ssnIn);
    my $fname = "$fn.xgmml";
    $ssnIn = "$baseDir/$fname";
}

my $ssnOut = "$outputPath/ssn.xgmml";
my $ssnOutZip = "$outputPath/ssn.zip";
my $ssnOutNamed = "$outputPath/$outputName.xgmml";
my $jobNamePrefix = $jobId ? "${jobId}_" : "";
my $ncMap = "$outputPath/nc.tab";


my $SS = new EFI::SchedulerApi(type => $schedType, queue => $queue, resource => [1, 1], dryrun => $dryRun);


#TODO: move this to a central location
if (not $ramReservation) {
    my $ramPredictionM = 0.02;
    my $ramSafety = $ssnInZip =~ m/\.zip$/ ? 20 : 10;
    my $fileSize = -s $ssnInZip;
    $fileSize *= 10 if $ssnInZip =~ m/\.zip$/;
    $fileSize = $fileSize / 1024 / 1024; # MB
    $ramReservation = $ramPredictionM * $fileSize + $ramSafety;
    $ramReservation = int($ramReservation + 0.5);
}

my $B = $SS->getBuilder();

$B->resource(1, 1, "${ramReservation}gb");
$B->addAction("source /etc/profile");
$B->addAction("module load $estModule");
$B->addAction("module load GD/2.73-IGB-gcc-8.2.0-Perl-5.28.1");
$B->addAction("source $extraPerl");
$B->addAction("cd $outputPath");
$B->addAction("$estPath/unzip_file.pl --in $ssnInZip --out $ssnIn") if $ssnInZip =~ /\.zip/i;
$B->addAction("$estPath/dump_connectivity.pl --input-xgmml $ssnIn --output-map $ncMap");
if (not $dumpOnly) {
    $B->addAction("$estPath/paint_ssn.pl --input $ssnIn \\
    --output $ssnOut \\
    --color-map $ncMap \\
    --node-col 1 --color-col 3 \\
    --primary-color \\
    --color-name \"Neighborhood Connectivity Color\" \\
    --extra-col 2-\"Neighborhood Connectivity\"");
    $B->addAction("$estPath/make_color_ramp.pl --input $ncMap --output $outputPath/legend.png");
    $B->addAction("mv $ssnOut $ssnOutNamed");
    $B->addAction("zip -jq $ssnOutZip $ssnOutNamed");
    $B->addAction("rm $ssnOutNamed");
}
$B->addAction("touch $outputPath/1.out.completed");


my $jobName = "${jobNamePrefix}compute_nc";
my $jobScript = "$outputPath/$jobName.sh";
$B->jobName($jobName);
$B->renderToFile($jobScript);
$jobId = $SS->submit($jobScript);
print "Compute NC job is:\n $jobId";

