#!/usr/bin/env perl

BEGIN {
    die "The efishared environments must be loaded before running this script" if not exists $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}

use strict;
use warnings;

use Getopt::Long qw(:config pass_through);
use FindBin;
use File::Basename;
use Digest::MD5;

use lib $FindBin::Bin . "/lib";

use EFI::SchedulerApi;
use EFI::Util qw(usesSlurm);


my $estPath = $FindBin::Bin;

my ($ssnIn, $jobDir, $outputFile, $resultsDirName);
my ($scheduler, $dryRun, $queue, $jobId, $configFile, $ramReservation, $ascore, $idListIn, $fastaIn);
my $result = GetOptions(
    "ssn-in=s"                  => \$ssnIn,
    "id-list-in=s"              => \$idListIn,
    "fasta-in=s"                => \$fastaIn,
    "job-dir=s"                 => \$jobDir,
    "results-dir-name=s"        => \$resultsDirName, # name of results sub-dir (e.g. output)
    "file-name=s"               => \$outputFile,
    "scheduler=s"               => \$scheduler,
    "dry-run"                   => \$dryRun,
    "queue=s"                   => \$queue,
    "job-id=s"                  => \$jobId,
    "ram=i"                     => \$ramReservation,
    "ascore=i"                  => \$ascore,
    "config=s"                  => \$configFile,
);

my $usage = <<USAGE
usage: $0 -ssnin <filename>

    --ssn-in            path to file of original ssn network to process
    --scheduler         scheduler type (default to torque, but also can be slurm)
    --dry-run           only generate the scripts, don't submit to queue
    --queue             the cluster queue to use
    --ascore            alignment score of input SSN
    --ram               the amount of RAM to reserve (for parsing the SSN)

The only required argument is --ssn-in, all others have defaults.
USAGE
;


$jobDir = $ENV{PWD} if not $jobDir;
$resultsDirName = "output" if not $resultsDirName;
my $outputPath = "$jobDir/$resultsDirName";
mkdir $outputPath;

$queue = $ENV{EFI_QUEUE} if not $queue;
$configFile = $ENV{EFI_CONFIG} if not $configFile or not -f $configFile;
if (not $configFile or not -f $configFile) {
    die "Either the configuration file or the EFI_CONFIG environment variable must be set\n$usage";
}
my $estModule = $ENV{EFI_EST_MOD};
my $efiEstTools = $ENV{EFI_EST};
my $efiDbMod = $ENV{EFI_DB_MOD};
my $extraPerl = "$ENV{EFI_PERL_ENV}";

if ($ssnIn) {
    $ssnIn = "$ENV{PWD}/$ssnIn" if $ssnIn !~ m/^\//;
    die "--ssn-in $ssnIn does not exist or has a zero size\n$usage" if not $ssnIn or not -s $ssnIn;
} elsif ($idListIn and -s $idListIn and $fastaIn and -s $fastaIn) {
    $ssnIn = "";
} else {
    die "Requires --ssn-in OR --id-list-in and --fasta-in";
}

die "$usage\nERROR: missing --queue parameter" if not $queue;

my $schedType = "torque";
$schedType = "slurm" if (defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm());


my $ssnInZip = $ssnIn;
if ($ssnInZip =~ /\.zip$/i) {
    my ($fn, $fp, $fx) = fileparse($ssnIn);
    my $fname = "$fn.xgmml";
    $ssnIn = "$jobDir/$fname";
}

my $jobNamePrefix = $jobId ? "${jobId}_" : "";
my $outIdList = "$outputPath/id_list.txt";

my $clusterDir = "$outputPath/clusters";

$outputFile = "conv_ratio.txt" if not $outputFile;
if ($outputFile !~ m%^/%) {
    $outputFile = "$outputPath/$outputFile";
}

my $np = 48;
my $blasthits = 1000000;
my $evalue = $ascore ? "1e-$ascore" : "1e-5";


my $SS = new EFI::SchedulerApi(type => $schedType, queue => $queue, resource => [1, 1], dryrun => $dryRun);


#TODO: move this to a central location
if (not $ramReservation and $ssnIn) {
    my $ramPredictionM = 0.02;
    my $ramSafety = $ssnInZip =~ m/\.zip$/ ? 20 : 10;
    my $fileSize = -s $ssnInZip;
    $fileSize *= 10 if $ssnInZip =~ m/\.zip$/;
    $fileSize = $fileSize / 1024 / 1024; # MB
    $ramReservation = $ramPredictionM * $fileSize + $ramSafety;
    $ramReservation = int($ramReservation + 0.5);
}

my $B = $SS->getBuilder();

my $maxJobs = 6;

my $blastJobId = "";
my @a = (('a'..'z'), 0..9);
$blastJobId .= $a[rand(@a)] for 1..5;
my $blastJobPrefix = "CR_$blastJobId";

mkdir $clusterDir;

$B->resource(1, 1, "${ramReservation}gb");
$B->addAction("source /etc/profile");
$B->addAction("module load $estModule");
$B->addAction("module load $efiDbMod");
$B->addAction("source $extraPerl");
$B->addAction("cd $outputPath");
if ($ssnIn) {
    $B->addAction("$estPath/unzip_file.pl --in $ssnInZip --out $ssnIn") if $ssnInZip =~ /\.zip/i;
    $B->addAction("$estPath/expand_ssn.pl --input $ssnIn --output $outIdList");
    $B->addAction("$estPath/util/get_fasta.pl --input $outIdList --clusters --output-dir $clusterDir");
} else {
    $outIdList = $idListIn;
    my @clusters = getClusterNumbers($idListIn);
    foreach my $cluster (@clusters) {
        my $cDir = "$clusterDir/cluster_$cluster";
        $B->addAction("mkdir -p $cDir");
        #TODO: copy the appropriate FASTA file in.  Currently this only is used and works for the rSAM.org project.
        $B->addAction("cp $fastaIn $cDir/allsequences.fa");
    }
}

$B->addAction("mkdir -p $clusterDir");
$B->addAction("$estPath/make_blast_jobs.pl --input-ids $outIdList --output-dir $clusterDir --job-name-prefix blast_$blastJobPrefix --max-jobs $maxJobs --queue $queue --evalue $evalue");

my $jobName = "prep_$blastJobPrefix";
my $jobScript = "$outputPath/$jobName.sh";
$B->jobName("$jobNamePrefix$jobName");
$B->renderToFile($jobScript);
my $prevJobId = $SS->submit($jobScript);
print "Get and split FASTA job is:\n $prevJobId";


$B = $SS->getBuilder();

#TODO: fix this for console-based execution
$B->resource(1, 1, "1gb");
$B->dependency(0, $prevJobId);
$B->addAction(<<CODE);

echo "Wait for BLAST jobs to start up"
sleep 60

echo "Waiting for $blastJobPrefix to finish up"
while squeue --partition efi,efi-mem --format "%i,%j" | grep blast_$blastJobPrefix > /dev/null
do
    sleep 30
    echo "Still waiting"
done

$estPath/calc_blast_stats.pl --cluster-dir $clusterDir --seq-count-output $outputFile --cluster-map $outIdList

echo "Finished up"

CODE
$B->addAction("touch  $outputPath/1.out.completed");


$jobName = "wait_${blastJobPrefix}_blast";
$jobScript = "$outputPath/$jobName.sh";
$B->jobName("$jobNamePrefix$jobName");
$B->renderToFile($jobScript);
$prevJobId = $SS->submit($jobScript);
print "Wait for BLAST job is:\n $prevJobId";







sub getClusterNumbers {
    my $file = shift;

    my %clusters;

    open my $fh, "<", $file or die "Unable to read file $file: $!";
    while (<$fh>) {
        chomp;
        my @p = split(m/\t/);
        $clusters{$p[1]} = 1;
    }
    close $fh;

    return keys %clusters;
}




__END__

























$B->addAction("$efiEstTools/split_fasta.pl --parts $np --tmp $fracOutputDir --source $sequenceFile");
$B->addAction("formatdb -i $sequenceFile -n database -p T -o T ");

my $jobName = "conv_get_fasta";
my $jobScript = "$outputPath/$jobName.sh";
$B->jobName("$jobNamePrefix$jobName");
$B->renderToFile($jobScript);
my $prevJobId = $SS->submit($jobScript);
print "Get and split FASTA job is:\n $prevJobId";


$B = $S->getBuilder();
mkdir $blastOutputDir;

$B->setScriptAbortOnError(0); # Disable SLURM aborting on errors, since we want to catch the BLAST error and report it to the user nicely
$B->jobArray("1-$np") if $blast eq "blast";
$B->dependency(0, $prevJobId);
$B->resource(1, 1, "5gb");

$B->addAction("export BLASTDB=$outputPath");
$B->addAction("module load $efiDbMod");
$B->addAction("module load $estModule");
$B->addAction("blastall -p blastp -i $fracOutputDir/fracfile-{JOB_ARRAYID}.fa -d $outputPath/database -m 8 -e $evalue -b $blasthits -o $blastOutputDir/blastout-{JOB_ARRAYID}.fa.tab");

$jobName = "conv_blast";
$jobScript = "$outputPath/$jobName.sh";
$B->jobName("$jobNamePrefix$jobName");
$B->renderToFile($jobScript);
$prevJobId = $SS->submit($jobScript);
print "BLAST job is:\n $prevJobId";


my $blastFinalFile = "$outputPath/blastfinal.tab";

$B = $S->getBuilder();
$B->resource(1, 1, "5gb");
$B->dependency(1, $prevJobId);
$B->addAction("cat $blastOutputDir/blastout-*.tab |grep -v '#'|cut -f 1,2,3,4,12 >$blastFinalFile")
$B->addAction("$estPath/dump_connectivity.pl --input-blast $blastFinalFile --output-map $ncMap");

$jobName = "conv_calc";
$jobScript = "$outputPath/$jobName.sh";
$B->jobName("$jobNamePrefix$jobName");
$B->renderToFile($jobScript);
$prevJobId = $SS->submit($jobScript);

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
$B->addAction("touch $outputPath/1.out.completed");


my $jobName = "${jobNamePrefix}compute_nc";
my $jobScript = "$outputPath/$jobName.sh";
$B->jobName($jobName);
$B->renderToFile($jobScript);
$jobId = $SS->submit($jobScript);
print "Compute NC job is:\n $jobId";

