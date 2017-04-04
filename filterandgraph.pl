#!/usr/bin/env perl

#version 0.9.2 no changes
#version 0.9.7 added options and code for working with Slurm scheduler

#this program allows you to filter the results of generatedata and see the graph results

#this program creates scrpts and submit them on clusters with torque that use the following perl files
#filterblast.pl            Filters 1.out files to remove unwanted information, creates 2.out file
#quart-align.pl            generates the alignment length quartile graph
#quart-perid.pl            generates the percent identity quartile graph
#sipmlegraphs.pl        generates sequence length and alignment score distributions

use File::Basename;
use Cwd qw(abs_path);
use lib dirname(abs_path(__FILE__));
use Getopt::Long;
use Biocluster::SchedulerApi;

$result=GetOptions ("filter=s"      => \$filter,
                    "minval=s"      => \$minval,
                    "queue=s"       => \$queue,
                    "tmp=s"         => \$tmpdir,
                    "maxlen=i"      => \$maxlen,
                    "minlen=i"      => \$minlen,
                    "incfrac=f"     => \$incfrac,
                    "scheduler=s"   => \$scheduler,     # to set the scheduler to slurm
                    "dryrun"        => \$dryrun,        # to print all job scripts to STDOUT and not execute the job
                    "oldapps"       => \$oldapps        # to module load oldapps for biocluster2 testing
                );

require "shared.pl";

$toolpath=$ENV{'EFIEST'};
$efiestmod=$ENV{'EFIESTMOD'};
#$toolpath="/home/groups/efi/devel";
$graphmultiplier=1.4;
$xinfo=500;
#$queue.=" -l nodes=compute-4-0";

#because variable values are important for filterblast and creating folder names we need to set defaults

#minlen and maxlen defaulted to zero if not assigned.
if(defined $minlen){
}else{
  $minlen=0;
}

if(defined $maxlen){

}else{
  $maxlen=0;
}

#if no filter set to bit
if(defined $filter){

}else{
  $filter="bit";
}

#if no minval, set to zero

if(defined $minval){

}else{
  $minval=0;
}


if(defined $queue){
}else{
  $queue="default";
}
print "queue is $queue\n";

if(defined $incfrac){
}else{
  $incfrac=.99;
}
print "incfrac is $incfrac\n";


#quit if the xgmml files have been created in this directory
#testing with percent_identity.png because I am lazy
if(-s "$tmpdir/$filter-$minval-$minlen-$maxlen/percent_identity.png"){
  print "Graphs appears to have already been completed, exiting\n";
  exit;
}

print "Data from runs will be saved to $tmpdir/$filter-$minval-$minlen-$maxlen/\n";

my $schedType = "torque";
$schedType = "slurm" if (defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm());
my $usesSlurm = $schedType eq "slurm";
if (defined($oldapps)) {
    $oldapps = $usesSlurm;
} else {
    $oldapps = 0;
}
my $S = new Biocluster::SchedulerApi('type' => $schedType);
my $B = $S->getBuilder();
$B->queue($queue);
$B->resource(1, 1);

#dont refilter if it has already been done
unless( -d "$tmpdir/$filter-$minval-$minlen-$maxlen"){
  mkdir "$tmpdir/$filter-$minval-$minlen-$maxlen" or die "could not make analysis folder $tmpdir/$filter-$minval-$minlen-$maxlen\n";

  submit the job for filtering out extraneous edges

  $fh = getFH(">$tmpdir/$filter-$minval-$minlen-$maxlen/filterblast.sh", $dryrun) or die "could not create blast submission script $tmpdir/fullxgmml.sh\n";
  $B->queue($queue);
  $B->resource(1, 1);
  $B->render($fh);
  print $fh "module load oldapps\n" if $oldapps;
  print $fh "module load $efiestmod\n";
  print $fh "$toolpath/filterblast.pl -blastin $ENV{PWD}/$tmpdir/1.out -blastout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -fastain $ENV{PWD}/$tmpdir/sequences.fa -fastaout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/sequences.fa -filter $filter -minval $minval -maxlen $maxlen -minlen $minlen\n";
  closeFH($fh, dryrun);

  $filterjob=doQsub("$tmpdir/$filter-$minval-$minlen-$maxlen/filterblast.sh", $dryrun, $schedType);
  print "Filterblast job is:\n $filterjob";

  @filterjobline=split /\./, $filterjob;
}else{
  print "Using prior filter\n";
}

#submit the quartiles scripts, should not run until filterjob is finished
#nothing else depends on this scipt

$fh = getFH(">$tmpdir/$filter-$minval-$minlen-$maxlen/quartalign.sh", $dryrun) or die "could not create blast submission script $tmpdir/$filter-$minval-$minlen-$maxlen/quartalign.sh\n";
$B->queue($queue);
$B->resource(1, 1);
if(defined $filterjob){
  $B->dependency(0, @filterjobline[0]); 
}
$B->render($fh);
print $fh "module load oldapps\n" if $oldapps;
print $fh "module load $efiestmod\n";
print $fh "$toolpath/quart-align.pl -blastout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -align $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/alignment_length.png\n";
closeFH($fh, dryrun);

$quartalignjob=doQsub("$tmpdir/$filter-$minval-$minlen-$maxlen/quartalign.sh", $dryrun, $schedType);
print "Quartile Align job is:\n $quartalignjob";

$fh = getFH(">$tmpdir/$filter-$minval-$minlen-$maxlen/quartpid.sh", $dryrun) or die "could not create blast submission script $tmpdir/$filter-$minval-$minlen-$maxlenr/quartpid.sh\n";
$B->queue($queue);
$B->resource(1, 1);
if(defined $filterjob){
  $B->dependency(0, @filterjobline[0]); 
}
$B->mailEnd();
$B->render($fh);
print $fh "module load oldapps\n" if $oldapps;
print $fh "module load $efiestmod\n";
print $fh "$toolpath/quart-perid.pl -blastout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -pid $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/percent_identity.png\n";
closeFH($fh, dryrun);

$quartpidjob=doQsub("$tmpdir/$filter-$minval-$minlen-$maxlen/quartpid.sh", $dryrun, $schedType);
print "Quartiles Percent Identity job is:\n $quartpidjob";

$fh = getFH(">$tmpdir/$filter-$minval-$minlen-$maxlen/simplegraphs.sh", $dryrun) or die "could not create blast submission script $tmpdir/$filter-$minval-$minlen-$maxlen/simplegraphs.sh\n";
print $fh "#!/bin/bash\n";
print $fh "#PBS -j oe\n";
print $fh "#PBS -S /bin/bash\n";
$B->queue($queue);
$B->resource(1, 1);
if(defined $filterjob){
  $B->dependency(0, @filterjobline[0]); 
}
$B->render($fh);
print $fh "module load oldapps\n" if $oldapps;
print $fh "module load $efiestmod\n";
print $fh "$toolpath/simplegraphs.pl -blastout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -maxlen $maxlen -minlen $minlen -edges $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/number_of_edges.png -fasta $ENV{PWD}/$tmpdir/sequences.fa -lengths $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/length_histogram.png -incfrac $incfrac\n";
closeFH($fh, dryrun);

$simplegraphjob=doQsub("$tmpdir/$filter-$minval-$minlen-$maxlen/simplegraphs.sh", $dryrun, $schedType);
print "Simplegraphs job is:\n $simplegraphjob";




