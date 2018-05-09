#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

#version 0.9.2 no changes
#version 0.9.7 added options and code for working with Slurm scheduler

#this program will analyze data from a folder created in the generatedata step, the most important parts being the 1.out and struct.out files

#this program creates scripts and submits them on clusters with torque schedulers
#filterblast.pl            Filters 1.out files to remove unwanted information, creates 2.out file
#xgmml_100_create.pl        Creates a truely 100% xgmml (all nodes and edges) from stuct.out and 2.out files
#xgmml_create_al.pl        Creates xgmml repnode networks from struct.out, 2.out, and cdit output
#stats.pl            Displays number of edges and nodes in each xgmml


use FindBin;
use Getopt::Long;
use EFI::SchedulerApi;
use EFI::Util qw(usesSlurm);

my ($filter, $minval, $queue, $relativeGenerateDir, $maxlen, $minlen, $title, $maxfull, $jobId, $lengthOverlap,
    $customClusterFile, $customClusterDir, $scheduler, $dryrun, $config, $parentId, $parentDir);
my $result = GetOptions(
    "filter=s"              => \$filter,
    "minval=s"              => \$minval,
    "queue=s"               => \$queue,
    "tmp=s"                 => \$relativeGenerateDir,
    "maxlen:i"              => \$maxlen,
    "minlen:i"              => \$minlen,
    "title:s"               => \$title,
    "maxfull:i"             => \$maxfull,
    "job-id=i"              => \$jobId,
    "lengthdif=i"           => \$lengthOverlap,
    "custom-cluster-file=s" => \$customClusterFile,
    "custom-cluster-dir=s"  => \$customClusterDir,
    "parent-id=s"           => \$parentId,
    "parent-dir=s"          => \$parentDir,
    "scheduler=s"           => \$scheduler,     # to set the scheduler to slurm 
    "dryrun"                => \$dryrun,        # to print all job scripts to STDOUT and not execute the job
    "config"                => \$config,        # config file path, if not given will look for EFICONFIG env var
);

die "The efiest and efidb environments must be loaded in order to run $0" if not $ENV{EFIEST} or not $ENV{EFIESTMOD} or not $ENV{EFIDBMOD};
die "The Perl environment must be loaded in order to run $0" if $ENV{LOADEDMODULES} !~ m/\bperl\b/i; # Ensure that the Perl module is loaded (e.g. module load Perl)

my $toolpath = $ENV{EFIEST};
my $efiEstMod = $ENV{EFIESTMOD};
my $efiDbMod = $ENV{EFIDBMOD};
(my $perlMod = $ENV{LOADEDMODULES}) =~ s/^.*\b(perl)\b.*$/$1/i;

my $dbver = "";
if (-f "$relativeGenerateDir/database_version") {
    $dbver = `head -1 $relativeGenerateDir/database_version`;
    chomp $dbver;
}
if (not $dbver) {
    ($dbver = $efiDbMod) =~ s/\D//g;
}

$minlen = 0             unless defined $minlen;
$maxlen = 50000         unless defined $maxlen;
$filter = "bit"         unless defined $filter;
$minval = 0             unless defined $minval;
$title = "Untitled"     unless defined $title;
$queue = "efi"          unless defined $queue;
$lengthOverlap = 1         unless (defined $lengthOverlap and $lengthOverlap);

(my $safeTitle = $title) =~ s/[^A-Za-z0-9_\-]/_/g;
$safeTitle .= "_";

if (defined $jobId and $jobId) {
    $safeTitle = $jobId . "_" . $safeTitle;
}

if (defined $maxfull and $maxfull !~ /^\d+$/) {
    die "maxfull must be an integer\n";
} else {
    $maxfull = 10000000;
}


if (not defined $relativeGenerateDir) {
    die "A temporary directory specified by -tmp is required for the program to run";
}

if (not defined $config or not -f $config) {
    if (exists $ENV{EFICONFIG}) {
        $config = $ENV{EFICONFIG};
    } else {
        die "--config file parameter is not specified.  module load efiest_v2 should take care of this.";
    }
}

my $baseOutputDir = $ENV{PWD};
my $generateDir = "$baseOutputDir/$relativeGenerateDir";
my $baseAnalysisDir = $generateDir;
if (defined $parentId and $parentId > 0 and defined $parentDir and -d $parentDir) {
    $generateDir = $parentDir;
}

my $analysisDir = "$baseAnalysisDir/$filter-$minval-$minlen-$maxlen";
if ($customClusterDir and $customClusterFile and -f "$baseAnalysisDir/$customClusterDir/$customClusterFile") {
    $analysisDir = "$baseAnalysisDir/$customClusterDir";
}

my $schedType = "torque";
$schedType = "slurm" if (defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm());
my $usesSlurm = $schedType eq "slurm";

my $wordOption = $lengthOverlap < 1 ? "-n 2" : "";

my $jobNamePrefix = (defined $jobId and $jobId) ? $jobId . "_" : ""; 



#quit if the xgmml files have been created in this directory
#testing with fullxgmml because I am lazy
if (-s "$analysisDir/${safeTitle}full.xgmml") {
    print "This run appears to have already been completed, exiting\n";
    exit;
}


my $logDir = "$baseOutputDir/log";
mkdir $logDir;
$logDir = "" if not -d $logDir;

my %schedArgs = (type => $schedType, queue => $queue, resource => [1, 1], dryrun => $dryrun);
$schedArgs{output_base_dirpath} = $logDir if $logDir;
my $S = new EFI::SchedulerApi(%schedArgs);
my $B = $S->getBuilder();
$B->resource(1, 1, "5gb");

print "Data from runs will be saved to $analysisDir\n";

my $filteredBlastFile = "$analysisDir/2.out";
#dont refilter if it has already been done

$B->addAction("module load $perlMod");
if ($customClusterDir and $customClusterFile) {
    #TODO: implement custom clustering
    $B->addAction("$toolpath/filter_custom.pl -blastin $generateDir/1.out -blastout $filteredBlastFile -custom-cluster-file $analysisDir/$customClusterFile");
    $B->addAction("cp $generateDir/allsequences.fa $analysisDir/sequences.fa");
} elsif (not -d $analysisDir){
    mkdir $analysisDir or die "could not make analysis folder $analysisDir\n";
    #submit the job for filtering out extraneous edges
    $B->addAction("$toolpath/filter_blast.pl -blastin $generateDir/1.out -blastout $filteredBlastFile -fastain $generateDir/allsequences.fa -fastaout $analysisDir/sequences.fa -filter $filter -minval $minval -maxlen $maxlen -minlen $minlen");
} else {
    print "Using prior filter\n";
}

$B->jobName("${jobNamePrefix}filterblast");
$B->renderToFile("$analysisDir/filterblast.sh");
$filterjob = $S->submit("$analysisDir/filterblast.sh", $dryrun);
chomp $filterjob;
print "Filterblast job is:\n $filterjob\n";
@filterjobline = split /\./, $filterjob;


#submit the job for generating the full xgmml file
#since struct.out is created in the first half, the full and repnode networks can all be generated at the same time
#depends on ffilterblast

$B = $S->getBuilder();
$B->dependency(0, @filterjobline[0]);
$B->resource(1, 1, "10gb");
$B->addAction("module load $efiEstMod");
$B->addAction("module load $perlMod");
my $outFile = "$analysisDir/${safeTitle}full_ssn.xgmml";
$B->addAction("$toolpath/xgmml_100_create.pl -blast=$filteredBlastFile -fasta $analysisDir/sequences.fa -struct $generateDir/struct.out -out $outFile -title=\"$title\" -maxfull $maxfull -dbver $dbver");
$B->addAction("zip -j $outFile.zip $outFile");
$B->jobName("${jobNamePrefix}fullxgmml");
$B->renderToFile("$analysisDir/fullxgmml.sh");

#submit generate the full xgmml script, job dependences should keep it from running till blast results have been created all blast out files are combined

$fulljob = $S->submit("$analysisDir/fullxgmml.sh", $dryrun, $schedType);
chomp $fulljob;
print "Full xgmml job is:\n $fulljob\n";

@fulljobline = split /\./, $fulljob;

#submit series of repnode network calculations
#depends on filterblast

$B = $S->getBuilder();
$B->jobArray("40,45,50,55,60,65,70,75,80,85,90,95,100");
$B->dependency(0, @fulljobline[0]);
$B->resource(1, 1, "10gb");
$B->addAction("module load $efiEstMod");
#$B->addAction("module load cd-hit");
$B->addAction("CDHIT=\$(echo \"scale=2; {JOB_ARRAYID}/100\" |bc -l)");
$B->addAction("cd-hit $wordOption -s $lengthOverlap -i $analysisDir/sequences.fa -o $analysisDir/cdhit\$CDHIT -n 2 -c \$CDHIT -d 0");
$outFile = "$analysisDir/${safeTitle}repnode-\${CDHIT}_ssn.xgmml";
$B->addAction("$toolpath/xgmml_create_all.pl -blast $filteredBlastFile -cdhit $analysisDir/cdhit\$CDHIT.clstr -fasta $analysisDir/allsequences.fa -struct $generateDir/struct.out -out $outFile -title=\"$title\" -dbver $dbver -maxfull $maxfull");
$B->addAction("zip -j $outFile.zip $outFile");
$B->jobName("${jobNamePrefix}cdhit");
$B->renderToFile("$analysisDir/cdhit.sh");

#submit the filter script, job dependences should keep it from running till all blast out files are combined
$repnodejob = $S->submit("$analysisDir/cdhit.sh", $dryrun, $schedType);
chomp $repnodejob;
print "Repnodes job is:\n $repnodejob\n";


@repnodejobline = split /\./, $repnodejob;

#test to fix dependancies
#depends on cdhit.sh
$B = $S->getBuilder();
$B->resource(1, 1, "1gb");
$B->dependency(1, @repnodejobline[0]);
$B->addAction("module load $efiEstMod");
$B->addAction("sleep 5");
$B->jobName("${jobNamePrefix}fix");
$B->renderToFile("$analysisDir/fix.sh");

#submit the filter script, job dependences should keep it from running till all blast out files are combined

$fixjob = $S->submit("$analysisDir/fix.sh", $dryrun, $schedType);
chomp $fixjob;
print "Fix job is:\n $fixjob\n";
@fixjobline = split /\./, $fixjob;

#submit series of repnode network calculations
#depends on filterblast
$B = $S->getBuilder();
$B->dependency(0, @fulljobline[0] . ":" . $fixjobline[0]);
$B->resource(1, 1, "5gb");
#$B->dependency(0, @fulljobline[0]); 
$B->mailEnd();
$B->addAction("module load $efiEstMod");
$B->addAction("$toolpath/stats.pl -run-dir $analysisDir -out $analysisDir/stats.tab");
$B->jobName("${jobNamePrefix}stats");
$B->renderToFile("$analysisDir/stats.sh");

#submit the filter script, job dependences should keep it from running till all blast out files are combined
$statjob = $S->submit("$analysisDir/stats.sh", $dryrun, $schedType);
chomp $statjob;
print "Stats job is:\n $statjob\n";


