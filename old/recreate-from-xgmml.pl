#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

#version 0.9.7 added options and code for working with Slurm scheduler

#this is just a qsub wrapper for regen-network.pl

use FindBin;
use Getopt::Long;
use EFI::SchedulerApi;
use EFI::Util qw(usesSlurm);

$result = GetOptions(
    "xgmml=s"       => \$xgmml,
    "oldtmp=s"      => \$oldtmp,
    "newtmp=s"      => \$newtmp,
    "queue=s"       => \$queue,
    "scheduler=s"   => \$scheduler,     # to set the scheduler to slurm
    "dryrun"        => \$dryrun,        # to print all job scripts to STDOUT and not execute the job
    "oldapps"       => \$oldapps        # to module load oldapps for biocluster2 testing
);



$toolpath=$ENV{'EFIEST'};
$efiestmod=$ENV{'EFIESTMOD'};


$xgmml="$ENV{PWD}/$xgmml" unless $xgmml=~/^\//;
$oldtmp="$ENV{PWD}/$oldtmp" unless $oldtmp=~/^\//;
$newtmp="$ENV{PWD}/$newtmp" unless $newtmp=~/^\//;
$queue="default" unless $queue=~/\w/;

mkdir $newtmp or die "cannnot create new temporary directory $newtmp\n";

my $schedType = "torque";
$schedType = "slurm" if (defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm());
my $usesSlurm = $schedType eq "slurm";
if (defined($oldapps)) {
    $oldapps = $usesSlurm;
} else {
    $oldapps = 0;
}

my $S = new EFI::SchedulerApi(type => $schedType, dryrun => $dryrun);
my $B = $S->getBuilder();

$B->queue($queue);
$B->resource(1, 1);
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiestmod");
$B->addAction("$toolpath/regen-network.pl -oldtmp $oldtmp -newtmp $newtmp -xgmml $xgmml");
$B->renderToFile("$newtmp/regen-network.sh");

# Submit generate the full xgmml script, job dependences should keep it from running till blast results have been created all blast out files are combined

$regenjob = $S->submit("$newtmp/regen-network.sh");
print "Job to regen network is is:\n $regenjob";

