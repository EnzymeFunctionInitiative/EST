#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

#version 0.9.2 no changes
#version 0.9.7 added options and code for working with Slurm scheduler

#this program allows you to filter the results of generatedata and see the graph results

#this program creates scrpts and submit them on clusters with torque that use the following perl files
#filterblast.pl            Filters 1.out files to remove unwanted information, creates 2.out file
#quart-align.pl            generates the alignment length quartile graph
#quart-perid.pl            generates the percent identity quartile graph
#sipmlegraphs.pl        generates sequence length and alignment score distributions

use FindBin;
use Getopt::Long;
use EFI::SchedulerApi;
use EFI::Util qw(usesSlurm);

$result = GetOptions(
    "filter=s"       => \$filter,
    "minval=s"       => \$minval,
    "queue=s"        => \$queue,
    "tmp=s"          => \$tmpdir,
    "maxlen=i"       => \$maxlen,
    "minlen=i"       => \$minlen,
    "incfrac=f"      => \$incfrac,
    "scheduler=s"    => \$scheduler,     # to set the scheduler to slurm
    "dryrun"         => \$dryrun,        # to print all job scripts to STDOUT and not execute the job
    "oldapps"        => \$oldapps        # to module load oldapps for biocluster2 testing
);


$toolpath = $ENV{'EFIEST'};
$efiestmod = $ENV{'EFIESTMOD'};
#$toolpath = "/home/groups/efi/devel";
$graphmultiplier = 1.4;
$xinfo = 500;
#$queue. = " -l nodes = compute-4-0";

# Because variable values are important for filterblast and creating folder names we need to set defaults

$minlen = 0 if not defined $minlen;
$maxlen = 0 if not defined $maxlen;
$filter = "bit" if not defined $filter;
$minval = 0 if not defined $minval;
$queue = "default" if not defined $queue;
$incfrac = .99 if not defined $incfrac;

print "queue is $queue\n";
print "incfrac is $incfrac\n";


#quit if the xgmml files have been created in this directory
#testing with percent_identity.png because I am lazy
if (-s "$tmpdir/$filter-$minval-$minlen-$maxlen/percent_identity.png") {
    print "Graphs appears to have already been completed, exiting\n";
    exit;
}

print "Data from runs will be saved to $tmpdir/$filter-$minval-$minlen-$maxlen/\n";

my $schedType = "torque";
$schedType = "slurm" if (defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm());
my $usesSlurm = $schedType eq "slurm";
if (defined $oldapps) {
    $oldapps = $usesSlurm;
} else {
    $oldapps = 0;
}
my $S = new EFI::SchedulerApi(type  => $schedType, dryrun  => $dryrun, $queue  => $queue, resource  => [1, 1]);
my $B = $S->getBuilder();

# Don't refilter if it has already been done
unless (-d "$tmpdir/$filter-$minval-$minlen-$maxlen") {
    mkdir "$tmpdir/$filter-$minval-$minlen-$maxlen" or die "could not make analysis folder $tmpdir/$filter-$minval-$minlen-$maxlen\n";

    # submit the job for filtering out extraneous edges
    $B->addAction("module load oldapps") if $oldapps;
    $B->addAction("module load $efiestmod");
    $B->addAction("$toolpath/filterblast.pl -blastin $ENV{PWD}/$tmpdir/1.out -blastout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -fastain $ENV{PWD}/$tmpdir/sequences.fa -fastaout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/sequences.fa -filter $filter -minval $minval -maxlen $maxlen -minlen $minlen");
    $B->renderToFile("$tmpdir/$filter-$minval-$minlen-$maxlen/filterblast.sh");

    $filterjob = $S->submit("$tmpdir/$filter-$minval-$minlen-$maxlen/filterblast.sh");
    print "Filterblast job is:\n $filterjob";

    @filterjobline = split /\./, $filterjob;
} else {
    print "Using prior filter\n";
}

#submit the quartiles scripts, should not run until filterjob is finished
#nothing else depends on this scipt

$B = $S->getBuilder();

if (defined $filterjob) {
    $B->dependency(0, @filterjobline[0]); 
}
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiestmod");
$B->addAction("$toolpath/quart-align.pl -blastout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -align $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/alignment_length.png");
$B->renderToFile("$tmpdir/$filter-$minval-$minlen-$maxlen/quartalign.sh");

$quartalignjob = $S->submit("$tmpdir/$filter-$minval-$minlen-$maxlen/quartalign.sh");
print "Quartile Align job is:\n $quartalignjob";

$B = $S->getBuilder();

if (defined $filterjob) {
    $B->dependency(0, @filterjobline[0]); 
}
$B->mailEnd();
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiestmod");
$B->addAction("$toolpath/quart-perid.pl -blastout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -pid $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/percent_identity.png");
$B->renderToFile("$tmpdir/$filter-$minval-$minlen-$maxlen/quartpid.sh");

$quartpidjob = $S->submit("$tmpdir/$filter-$minval-$minlen-$maxlen/quartpid.sh");
print "Quartiles Percent Identity job is:\n $quartpidjob";

$B = $S->getBuilder();

if (defined $filterjob) {
    $B->dependency(0, @filterjobline[0]); 
}
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiestmod");
$B->addAction("$toolpath/simplegraphs.pl -blastout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -maxlen $maxlen -minlen $minlen -edges $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/number_of_edges.png -fasta $ENV{PWD}/$tmpdir/sequences.fa -lengths $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/length_histogram.png -incfrac $incfrac");
$B->renderToFile("$tmpdir/$filter-$minval-$minlen-$maxlen/simplegraphs.sh");

$simplegraphjob = $S->submit("$tmpdir/$filter-$minval-$minlen-$maxlen/simplegraphs.sh");
print "Simplegraphs job is:\n $simplegraphjob";




