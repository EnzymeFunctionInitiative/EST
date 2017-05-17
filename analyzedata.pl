#!/usr/bin/env perl

#version 0.9.2 no changes
#version 0.9.7 added options and code for working with Slurm scheduler

#this program will analyze data from a folder created in the generatedata step, the most important parts being the 1.out and struct.out files

#this program creates scripts and submits them on clusters with torque schedulers
#filterblast.pl			Filters 1.out files to remove unwanted information, creates 2.out file
#xgmml_100_create.pl		Creates a truely 100% xgmml (all nodes and edges) from stuct.out and 2.out files
#xgmml_create_al.pl		Creates xgmml repnode networks from struct.out, 2.out, and cdit output
#stats.pl			Displays number of edges and nodes in each xgmml


use FindBin;
use lib "$FindBin::Bin/lib";
use Getopt::Long;
use Biocluster::SchedulerApi;
use Biocluster::Util qw(usesSlurm);

$result = GetOptions(
    "filter=s"    => \$filter,
    "minval=s"	  => \$minval,
    "queue=s"	  => \$queue,
    "tmp=s"	      => \$tmpdir,
    "maxlen:i"	  => \$maxlen,
    "minlen:i"	  => \$minlen,
    "title:s"	  => \$title,
    "maxfull:i"	  => \$maxfull,
    "scheduler=s" => \$scheduler,     # to set the scheduler to slurm 
    "dryrun"      => \$dryrun,        # to print all job scripts to STDOUT and not execute the job
    "oldapps"     => \$oldapps,       # to module load oldapps for biocluster2 testing
    "config"      => \$config,        # config file path, if not given will look for EFICONFIG env var
);


$toolpath = $ENV{'EFIEST'};
$efiestmod = $ENV{'EFIESTMOD'};

$dbver = `head -1 $tmpdir/database_version`;
chomp $dbver;

$minlen = 0             unless defined $minlen;
$maxlen = 0             unless defined $maxlen;
$filter = "bit"         unless defined $filter;
$minval = 0             unless defined $minval;
$title = "Untitled"     unless defined $title;
$queue = "efi"          unless defined $queue;

(my $safeTitle = $title) =~ s/[^A-Za-z0-9_\-]/_/g;
$safeTitle .= "_";
#my $safeTitle = "";

if (defined $maxfull and $maxfull !~ /^\d+$/) {
    die "maxfull must be an integer\n";
} else {
    $maxfull = 10000000;
}


if (not defined $tmpdir) {
    die "A temporary directory specified by -tmp is required for the program to run";
}

if (not defined $config or not -f $config) {
    if (exists $ENV{EFICONFIG}) {
        $config = $ENV{EFICONFIG};
    } else {
        die "--config file parameter is not specified.  module load efiest_v2 should take care of this.";
    }
}

#quit if the xgmml files have been created in this directory
#testing with fullxgmml because I am lazy
if (-s "$tmpdir/$filter-$minval-$minlen-$maxlen/${safeTitle}full.xgmml") {
    print "This run appears to have already been completed, exiting\n";
    exit;
}

my $schedType = "torque";
$schedType = "slurm" if (defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm());
my $usesSlurm = $schedType eq "slurm";
if (defined($oldapps)) {
    $oldapps = $usesSlurm;
} else {
    $oldapps = 0;
}

my $S = new Biocluster::SchedulerApi(type => $schedType, queue => $queue, resource => [1, 1], dryrun => $dryrun);
my $B = $S->getBuilder();

print "Data from runs will be saved to $tmpdir/$filter-$minval-$minlen-$maxlen/\n";

#dont refilter if it has already been done
$priorFilter = 0;
if (not -d "$tmpdir/$filter-$minval-$minlen-$maxlen"){
    mkdir "$tmpdir/$filter-$minval-$minlen-$maxlen" or die "could not make analysis folder $tmpdir/$filter-$minval-$minlen-$maxlen\n";

    #submit the job for filtering out extraneous edges
    $B->addAction("module load oldapps") if $oldapps;
    $B->addAction("module load perl/5.16.1");
    $B->addAction("$toolpath/filterblast.pl -blastin $ENV{PWD}/$tmpdir/1.out -blastout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -fastain $ENV{PWD}/$tmpdir/allsequences.fa -fastaout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/sequences.fa -filter $filter -minval $minval -maxlen $maxlen -minlen $minlen");
    $B->renderToFile("$tmpdir/$filter-$minval-$minlen-$maxlen/filterblast.sh");

    $filterjob = $S->submit("$tmpdir/$filter-$minval-$minlen-$maxlen/filterblast.sh", $dryrun);
    print "Filterblast job is:\n $filterjob";

    @filterjobline = split /\./, $filterjob;
} else {
    print "Using prior filter\n";
    $priorFilter = 1;
}

#submit the job for generating the full xgmml file
#since struct.out is created in the first half, the full and repnode networks can all be generated at the same time
#depends on ffilterblast

$B = $S->getBuilder();
$B->dependency(0, @filterjobline[0])
    if not $priorFilter;
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiestmod");
my $outFile = "$ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/${safeTitle}full.xgmml";
$B->addAction("$toolpath/xgmml_100_create.pl -blast=$ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -fasta $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/sequences.fa -struct $ENV{PWD}/$tmpdir/struct.out -out $outFile -title=\"$title\" -maxfull $maxfull -dbver $dbver");
$B->addAction("zip -j $outFile.zip $outFile");
$B->renderToFile("$tmpdir/$filter-$minval-$minlen-$maxlen/fullxgmml.sh");

#submit generate the full xgmml script, job dependences should keep it from running till blast results have been created all blast out files are combined

$fulljob = $S->submit("$tmpdir/$filter-$minval-$minlen-$maxlen/fullxgmml.sh", $dryrun, $schedType);
print "Full xgmml job is:\n $fulljob";

@fulljobline = split /\./, $fulljob;

#submit series of repnode network calculations
#depends on filterblast

$B = $S->getBuilder();
$B->jobArray("40,45,50,55,60,65,70,75,80,85,90,95,100");
$B->dependency(0, @fulljobline[0]);
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiestmod");
#$B->addAction("module load cd-hit");
$B->addAction("CDHIT=\$(echo \"scale=2; \${PBS_ARRAYID}/100\" |bc -l)");
$B->addAction("cd-hit -i $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/sequences.fa -o $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/cdhit\$CDHIT -n 2 -c \$CDHIT -d 0");
$outFile = "$ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/${safeTitle}repnode-\$CDHIT.xgmml";
$B->addAction("$toolpath/xgmml_create_all.pl -blast $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -cdhit $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/cdhit\$CDHIT.clstr -fasta $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/allsequences.fa -struct $ENV{PWD}/$tmpdir/struct.out -out $outFile -title=\"$title\" -dbver $dbver");
$B->addAction("zip -j $outFile.zip $outFile");
$B->renderToFile("$tmpdir/$filter-$minval-$minlen-$maxlen/cdhit.sh");

#submit the filter script, job dependences should keep it from running till all blast out files are combined
$repnodejob = $S->submit("$tmpdir/$filter-$minval-$minlen-$maxlen/cdhit.sh", $dryrun, $schedType);
print "Repnodes job is:\n $repnodejob";


@repnodejobline = split /\./, $repnodejob;

#test to fix dependancies
#depends on cdhit.sh
$B = $S->getBuilder();
$B->dependency(1, @repnodejobline[0]);
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiestmod");
$B->addAction("sleep 5");
$B->renderToFile("$tmpdir/$filter-$minval-$minlen-$maxlen/fix.sh");

#submit the filter script, job dependences should keep it from running till all blast out files are combined

$fixjob = $S->submit("$tmpdir/$filter-$minval-$minlen-$maxlen/fix.sh", $dryrun, $schedType);
print "Fix job is:\n $fixjob";
@fixjobline = split /\./, $fixjob;

#submit series of repnode network calculations
#depends on filterblast
$B = $S->getBuilder();
$B->dependency(0, @fulljobline[0] . ":" . $fixjobline[0]);
#$B->dependency(0, @fulljobline[0]); 
$B->mailEnd();
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiestmod");
$B->addAction("$toolpath/stats.pl -tmp $ENV{PWD}/$tmpdir -run $filter-$minval-$minlen-$maxlen -out $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/stats.tab");
$B->renderToFile("$tmpdir/$filter-$minval-$minlen-$maxlen/stats.sh");

#submit the filter script, job dependences should keep it from running till all blast out files are combined
$statjob = $S->submit("$tmpdir/$filter-$minval-$minlen-$maxlen/stats.sh", $dryrun, $schedType);
print "Stats job is:\n $statjob";


