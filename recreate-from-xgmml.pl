#!/usr/bin/env perl

#version 0.9.7 added options and code for working with Slurm scheduler

#this is just a qsub wrapper for regen-network.pl

use lib "../";
use Getopt::Long;
use Biocluster::SchedulerApi;

$result=GetOptions ("xgmml=s"       => \$xgmml,
                    "oldtmp=s"      => \$oldtmp,
                    "newtmp=s"      => \$newtmp,
                    "queue=s"       => \$queue,
                    "scheduler=s"   => \$scheduler,     # to set the scheduler to slurm
                    "dryrun"        => \$dryrun,        # to print all job scripts to STDOUT and not execute the job
                    "oldapps"       => \$oldapps        # to module load oldapps for biocluster2 testing
                   );

require "shared.pl";


$toolpath=$ENV{'EFIEST'};
$efiestmod=$ENV{'EFIESTMOD'};

unless($xgmml=~/^\//){
  $xgmml="$ENV{PWD}/$xgmml";
}

unless($oldtmp=~/^\//){
  $oldtmp="$ENV{PWD}/$oldtmp";
}

unless($newtmp=~/^\//){
  $newtmp="$ENV{PWD}/$newtmp";
}

unless($queue=~/\w/){
  $queue="default";
}

mkdir $newtmp or die "cannnot create new temporary directory $newtmp\n";

my $schedType = "torque";
$schedType = "slurm" if defined($scheduler) and $scheduler eq "slurm";
my $S = new Biocluster::SchedulerApi('type' => $schedType);
my $B = $S->getBuilder();
$B->queue($queue);
$B->resource(1, 1);

$fh = getFH(">$newtmp/regen-network.sh", $dryrun) or die "could not create blast submission script $tmpdir/regen-network.sh\n";
$B->queue($queue);
$B->resource(1, 1);
print $fh "module load oldapps\n" if $schedType eq "slurm" and defined($oldapps);
print $fh "module load $efiestmod\n";
print $fh "$toolpath/regen-network.pl -oldtmp $oldtmp -newtmp $newtmp -xgmml $xgmml\n";
closeFH($fh, $dryrun);

#submit generate the full xgmml script, job dependences should keep it from running till blast results have been created all blast out files are combined

$regenjob=doQsub("$newtmp/regen-network.sh", $dryrun, $schedType);
print "Job to regen network is is:\n $regenjob";

