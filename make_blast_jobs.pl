#!/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use Data::Dumper;

#TODO: fix this
use lib $FindBin::Bin . "/../EFIShared/lib";

use EFI::SchedulerApi;
use EFI::Util qw(usesSlurm);



#--input-ids $outIdList --fasta-dir $clusterDir --output-dir $fracOutputDir --job-name-prefix $blastJobPrefix --max-jobs $maxJobs");
my ($inputIds, $outputDir, $namePrefix, $maxJobs, $evalue, $queue, $scheduler, $dryRun);
my $result = GetOptions(
    "input-ids=s"           => \$inputIds,
    "output-dir=s"          => \$outputDir,
    "job-name-prefix=s"     => \$namePrefix,
    "max-jobs=i"            => \$maxJobs,
    "evalue=s"              => \$evalue,
    "queue=s"               => \$queue,
    "scheduler=s"           => \$scheduler,
    "dry-run"               => \$dryRun,
);

die "Require --input-ids id list/cluster mapping file" if not $inputIds or not -f $inputIds;
die "Require --output-dir" if not $outputDir or not -d $outputDir;
die "Require --job-name-prefix" if not $namePrefix;

$queue = $ENV{EFI_QUEUE} if not $queue;
die "Require --queue or EFI_QUEUE" if not $queue;

$maxJobs = 4 if not $maxJobs;
$dryRun = defined $dryRun;

my $blasthits = 1000000;  
my $sortdir = '/scratch';
$evalue = $evalue ? $evalue : "1e-5";

my $estModule = $ENV{EFI_EST_MOD};
my $efiEstTools = $ENV{EFI_EST};

my $schedType = "torque";
$schedType = "slurm" if (defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm());
my $SS = new EFI::SchedulerApi(type => $schedType, queue => $queue, resource => [1, 1, "5gb"], dryrun => $dryRun);


my %sizes = getClusterSizes($inputIds);
my @bySize = sort { $sizes{$a} <=> $sizes{$b} } keys %sizes;
my $parts = partitionClusters($maxJobs, \@bySize, \%sizes);


foreach my $partNum (keys %$parts) {
    my @clusterIds = @{$parts->{$partNum}};
    my ($np, $ram) = getNumTasks(\@clusterIds, \%sizes);

    my $B = $SS->getBuilder();
    $B->addAction("module load $estModule");

    foreach my $clusterId (@clusterIds) {
        my $outDir = "$outputDir/cluster_$clusterId";
        my $fracDir = "$outDir/fractions";
        my $seqFile = "$outDir/sequences.fa";
        my $allSeqFile = "$outDir/allsequences.fa";
        $B->addAction("mkdir -p $fracDir");
        $B->addAction("mkdir -p $outDir/blast");
        $B->addAction("cd $outDir");
        #$B->addAction("cp $seqFile.bak $seqFile");
        #$B->addAction("sed '" . 's/^>[ts][rp]|\([^|]\+\)|.*/>\1/' . "' $seqFile.bak > $seqFile");
        #$B->addAction("mv $seqFile $allSeqFile");
        $B->addAction("cd-hit -d 0 -c 1 -s 1 -i $allSeqFile -o $seqFile -M 10000");
        $B->addAction("formatdb -i $seqFile -n database -p T -o T ");
        $B->addAction("$efiEstTools/split_fasta.pl -parts $np -tmp $fracDir -source $seqFile");
    }

    my $jobName = "${namePrefix}_${partNum}a";
    my $jobScript = "$outputDir/$jobName.sh";
    $B->jobName($jobName);
    $B->renderToFile($jobScript);
    my $jobId = $SS->submit($jobScript);
    
    $B = $SS->getBuilder();
    $B->dependency(0, $jobId);
    $B->jobArray("1-$np");

    foreach my $clusterId (@clusterIds) {
        my $outDir = "$outputDir/cluster_$clusterId";
        my $fracFile = "$outDir/fractions/fracfile-{JOB_ARRAYID}.fa";
        my $blastFile = "$outDir/blast/blastout-{JOB_ARRAYID}.fa.tab";
        $B->addAction("if [ -s \"$fracFile\" ]; then");
        $B->addAction("    blastall -p blastp -i $fracFile -d $outDir/database -m 8 -e $evalue -b $blasthits -o $blastFile");
        $B->addAction("else\necho \"$fracFile does not exist\";\nfi");
    }

    $jobName = "${namePrefix}_${partNum}b";
    $jobScript = "$outputDir/$jobName.sh";
    $B->jobName($jobName);
    $B->renderToFile($jobScript);
    $jobId = $SS->submit($jobScript);
    
    $B = $SS->getBuilder();
    $B->dependency(1, $jobId);
    $B->resource(1, 1, "${ram}gb");

    foreach my $clusterId (@clusterIds) {
        my $outDir = "$outputDir/cluster_$clusterId";
        my $blastFinalFile = "$outDir/blastall.tab";
        my $seqFile = "$outDir/sequences.fa";
        $B->addAction("cat $outDir/blast/blastout-*.tab |grep -v '#'|cut -f 1,2,3,4,12 > $blastFinalFile");
        #$B->addAction("sed '" . 's/[trsp]\+|\([A-Z0-9_\-\.]\+\)|[A-Z0-9_\-\.]\+' . "\t/\\1\t/g' $blastFinalFile > $blastFinalFile.2");
        #$B->addAction("mv $blastFinalFile.2 $blastFinalFile");
        $B->addAction("$efiEstTools/alphabetize.pl -in $blastFinalFile -out $outDir/alphabetized.blastfinal.tab -fasta $seqFile");
        $B->addAction("sort -T $sortdir -k1,1 -k2,2 -k5,5nr -t\$\'\\t\' $outDir/alphabetized.blastfinal.tab > $outDir/sorted.alphabetized.blastfinal.tab");
        $B->addAction("$efiEstTools/blastreduce-alpha.pl -blast $outDir/sorted.alphabetized.blastfinal.tab -out $outDir/unsorted.1.out");
        $B->addAction("sort -T $sortdir -k5,5nr -t\$\'\\t\' $outDir/unsorted.1.out > $outDir/1.out");
        $B->addAction("mv $outDir/1.out $outDir/mux.out");
        $B->addAction("$efiEstTools/demux.pl -blastin $outDir/mux.out -blastout $outDir/1.out -cluster $seqFile.clstr");
    }

    $jobName = "${namePrefix}_${partNum}c";
    $jobScript = "$outputDir/$jobName.sh";
    $B->jobName($jobName);
    $B->renderToFile($jobScript);
    $jobId = $SS->submit($jobScript);
}














sub getNumTasks {
    my $ids = shift;
    my $sizes = shift;

    my $np = 48;
    my $ram = 30;

    # First is largest
    my $ns = $sizes->{$ids->[$#$ids]};
    if ($ids->[1]) {
        $ns = int(($ns + $sizes->{$ids->[$#$ids-1]}) / 2);
    }

    if ($ns < 50) {
        $np = 1;
    } elsif ($ns < 200) {
        $np = 4;
    } elsif ($ns < 400) {
        $np = 8;
    } elsif ($ns < 800) {
        $np = 12;
    } elsif ($ns < 1200) {
        $np = 16;
    } elsif ($ns > 10000) {
        $ram = 150;
    }
    return ($np, $ram);
}


sub partitionClusters {
    my $numParts = shift;
    my $ids = shift;
    my $sizes = shift;
    my $parts = {};
    for (my $di = 0; $di < $numParts; $di++) {
        for (my $ai = $di; $ai < scalar @$ids; $ai += $numParts) {
            push @{$parts->{$di}}, $ids->[$ai] if $ai < scalar @$ids;
        }
    }
    return $parts;
}


sub getClusterSizes {
    my $idFile = shift;

    my %clusters;
    
    open my $fh, "<", $idFile;
    while (<$fh>) {
        chomp;
        my ($id, $cluster) = split(m/\t/);
        $cluster //= 1;
        next if $cluster =~ m/^S/i;
        push @{$clusters{$cluster}}, $id;
    }
    close $fh;

    my %sizes = map { $_ => scalar @{$clusters{$_}} } keys %clusters;

    return %sizes;
}


