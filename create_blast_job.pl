#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}

use warnings;
use strict;

use FindBin;
use File::Basename;
use Getopt::Long qw(:config pass_through);
use EFI::SchedulerApi;
use EFI::Util qw(usesSlurm getLmod);
use EFI::Config qw(cluster_configure);

use lib $FindBin::Bin . "/lib";
use BlastUtil;


my ($seq, $resultsDirName, $jobDir, $famEvalue, $evalue, $multiplexing, $lengthdif, $sim, $np, $blasthits, $queue, $memqueue);
my ($maxBlastResults, $seqCountFile, $ipro, $pfam, $unirefVersion, $unirefExpand, $fraction, $maxFullFamily, $LegacyGraphs);
my ($jobId, $inputId, $removeTempFiles, $scheduler, $dryrun, $configFile, $excludeFragments, $dbType, $taxSearch, $taxSearchInvert, $runSerial, $useNoModules, $envScripts);
my $result = GetOptions(
    "seq=s"             => \$seq,
    "results-dir-name=s"=> \$resultsDirName,
    "job-dir=s"         => \$jobDir,
    "evalue=s"          => \$famEvalue, # Due to the way the front-end is implemented, the -evalue parameter now is used for (optional) family input BLASTs.
    "blast-evalue=s"    => \$evalue,
    "multiplexing=s"    => \$multiplexing,
    "lengthdif=f"       => \$lengthdif,
    "sim=f"             => \$sim,
    "np=i"              => \$np,
    "blasthits=i"       => \$blasthits,
    "queue=s"           => \$queue,
    "memqueue=s"        => \$memqueue,
    "nresults=i"        => \$maxBlastResults,
    "seq-count-file=s"  => \$seqCountFile,
    "ipro=s"            => \$ipro,
    "pfam=s"            => \$pfam,
    "uniref-version=s"  => \$unirefVersion, # for families only
    "uniref-expand"     => \$unirefExpand,  # expand to include all homologues of UniRef seed sequences that are provided.
    "fraction=i"        => \$fraction,
    "maxsequence=s"     => \$maxFullFamily,
    "oldgraphs"         => \$LegacyGraphs,  # use the old graphing code
    "job-id=i"          => \$jobId,
    "blast-input-id=s"  => \$inputId,
    "remove-temp"       => \$removeTempFiles, # add this flag to remove temp files
    "scheduler=s"       => \$scheduler,     # to set the scheduler to slurm
    "dryrun"            => \$dryrun,        # to print all job scripts to STDOUT and not execute the job
    "config=s"          => \$configFile,    # new-style config file
    "exclude-fragments" => \$excludeFragments,
    "db-type=s"         => \$dbType, # uniprot, uniref50, uniref90  default to uniprot; if uniref expand IDs to include UniRef members as node attribute
    "tax-search=s"      => \$taxSearch,
    "tax-search-invert" => \$taxSearchInvert,
    "serial-script=s"   => \$runSerial,     # run in serial mode
    "no-modules"        => \$useNoModules,
    "env-scripts=s"     => \$envScripts,
);

die "Environment variables not set properly: missing EFI_DB variable" if not exists $ENV{EFI_DB};

my $efiEstTools = $ENV{EFI_EST};
my $efiEstMod = $ENV{EFI_EST_MOD};
my $efiDbMod = $ENV{EFI_DB_MOD};
my $databaseDir = $ENV{EFI_DB_DIR};
my $dbVer = $ENV{EFI_DB};

if (not $configFile or not -f $configFile) {
    $configFile = $ENV{EFI_CONFIG};
}

die "-config file argument is required" if not $configFile or not -f $configFile;
my $config = {};
cluster_configure($config, config_file_path => $configFile);


$jobDir = $ENV{PWD} if not $jobDir;
$resultsDirName = "output" if not $resultsDirName;
my $outputDir = "$jobDir/$resultsDirName";

print "db is: $dbVer\n";
mkdir $outputDir or die "Could not make directory $outputDir\n" if not -d $outputDir;

my $dbName = "combined";
my $blastUnirefVersion = "";
if ($dbType and ($dbType eq "uniref50" or $dbType eq "uniref90")) {
    $dbName = "$dbType";
    $blastUnirefVersion = substr($dbType, 6);
}
$dbName .= ($excludeFragments ? "_nf" : "") . ".fasta";

my $blastDb = "$databaseDir/$dbName";
my $perpass = 1000;
my $incfrac = 1; # was 0.95
my $maxhits = 5000;
my $sortdir = '/scratch';
$maxBlastResults = 100 if not $maxBlastResults;

if (not defined $evalue and defined $famEvalue) {
    $evalue = $famEvalue;
} elsif (not defined $evalue) {
    print "-evalue not specified, using default of 5\n";
    $evalue="1e-5";
} else {
    if ($evalue =~ /^\d+$/) {
        $evalue="1e-$evalue";
    }
}

if (not defined $famEvalue) {
    $famEvalue = $evalue;
}
$famEvalue = "1e-$famEvalue" if $famEvalue =~ /^\d+$/;

#defaults and error checking for multiplexing
if (not defined $multiplexing) {
    $multiplexing = "on";
} elsif ($multiplexing ne "on" and $multiplexing ne "off") {
    die "valid variables for multiplexing are either on or off\n";
}

if (defined $lengthdif) {
    if (not $lengthdif=~/\d+(\.\d)?/) {
        die "lengthdif must be in a format like 0.9d\n";
    }
} else {
    $lengthdif = 1;
}

if (defined $sim) {
    if (not $sim=~/\d+(\.\d)?/) {
        die "sim must be in a format like 0.9c\n";
    }   
} else {
    $sim = 1;
}

#you also have to specify the number of processors for blast
if (not defined $np) {
    $np = 48;
    #die "You must spefify the -np variable\n";
}

if (not defined $blasthits) {
    $blasthits=1000000;  
}

#default queues
if (not defined $queue) {
    print "-queue not specified, using default\n";
    $queue = "efi";
}
if (not defined $memqueue) {
    print "-memqueue not specifiied, using default\n";
    $memqueue = "efi";
}

$seqCountFile = "acc_counts.txt" if not $seqCountFile;
$seqCountFile = "$outputDir/$seqCountFile" if $seqCountFile !~ m%^/%;


# Set up the scheduler API so we can work with Torque or Slurm.
my $schedType = "torque";
$schedType = "slurm" if (defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm());
my $usesSlurm = $schedType eq "slurm";

# Defaults for fraction of sequences to fetch
if (defined $fraction and $fraction !~ /^\d+$/ and $fraction <= 0) {
    die "if fraction is defined, it must be greater than zero\n";
} elsif (not defined $fraction) {
    $fraction = 1;
}

$excludeFragments = defined($excludeFragments);

my $useModuleSystem = not $useNoModules;

my $gdMod = "GD/2.73-IGB-gcc-8.2.0-Perl-5.28.1";


my $logDir = "$jobDir/log";
mkdir $logDir;
$logDir = "" if not -d $logDir;
my %schedArgs = (type => $schedType, queue => $queue, resource => [1, 1, "35gb"], dryrun => $dryrun);
$schedArgs{output_base_dirpath} = $logDir if $logDir;
$schedArgs{extra_path} = $config->{cluster}->{extra_path} if $config->{cluster}->{extra_path};
$schedArgs{run_serial} = $runSerial ? 1 : 0;
my $S = new EFI::SchedulerApi(%schedArgs);

my $B = $S->getBuilder();

initSerialScript($B) if $runSerial;

my $scriptDir = "$jobDir/scripts";
mkdir $scriptDir;
$scriptDir = $outputDir if not -d $scriptDir;

$maxFullFamily = 0 if not $maxFullFamily;

my $jobNamePrefix = $jobId ? $jobId . "_" : ""; 

my $queryFile = "$outputDir/query.fa";
my $allSeqFilename = "allsequences.fa";
my $allSeqFile = "$outputDir/$allSeqFilename";
my $filtSeqFilename = "sequences.fa";
my $filtSeqFile = "$outputDir/$filtSeqFilename";
my $accOutFile = "$outputDir/accessions.txt";
my $metadataFile = "$outputDir/" . EFI::Config::FASTA_META_FILENAME;

BlastUtil::save_input_sequence($queryFile, $seq, $inputId);

print "\nBlast for similar sequences and sort based off bitscore\n";

my @jobIds;

my $submitResult;

#TODO: handle fragment database
$B->setScriptAbortOnError(0); # Disable SLURM aborting on errors, since we want to catch the BLAST error and report it to the user nicely
$B->resource(1, 1, "70gb");
addModule($B, "module load $efiEstMod");
addModule($B, "module load $efiDbMod");
$B->addAction("cd $outputDir");
$B->addAction("blastall -p blastp -i $outputDir/query.fa -d $blastDb -m 8 -e $evalue -b $maxBlastResults -o $outputDir/initblast.out");
$B->addAction("OUT=\$?");
$B->addAction("if [ \$OUT -ne 0 ]; then");
$B->addAction("    echo \"BLAST failed; likely due to file format.\"");
$B->addAction("    echo \$OUT > $outputDir/1.out.failed");
$B->addAction("    exit 1");
$B->addAction("fi");
#queryId, subjectId, percIdentity, alnLength, mismatchCount, gapOpenCount, queryStart, queryEnd, subjectStart, subjectEnd, eVal, bitScore
#zINPUTSEQ  tr|A0A1U8QII3|A0A1U8QII3_EMENI  42.65   408     218     6       1       397     1       403     2e-99    311
#zINPUTSEQ	tr|A0A2V5H9D2|A0A2V5H9D2_ASPV1	100.00	398	 796
$B->addAction("cat $outputDir/initblast.out |grep -v '#'|cut -f 1,2,3,4,12 |sort -k5,5nr >$outputDir/blastfinal.tab");
$B->addAction("cat $outputDir/initblast.out |grep -v '#'|cut -f 2,11 |sort -k2nr > $outputDir/blast_hits.tab");
$B->addAction("SZ=`stat -c%s $outputDir/blastfinal.tab`");
$B->addAction("if [[ \$SZ == 0 ]]; then");
$B->addAction("    echo \"BLAST Failed. Check input sequence.\"");
$B->addAction("    touch $outputDir/1.out.failed");
$B->addAction("    exit 1");
$B->addAction("fi");
$B->jobName("${jobNamePrefix}initial_blast");
$B->renderToFile(getRenderFilePath("$scriptDir/initial_blast.sh"));

chomp($submitResult = $S->submit("$scriptDir/initial_blast.sh"));
print "initial blast job is:\n $submitResult\n";
my $initBlastJobId = getJobId($submitResult);
push @jobIds, $initBlastJobId;



my @args = (
    "-config=$configFile",
    "-seq-count-output $seqCountFile", "-sequence-output $allSeqFile", "-accession-output $accOutFile",
    "-meta-file $metadataFile",
);

push @args, "-pfam $pfam" if $pfam;
push @args, "-ipro $ipro" if $ipro;
push @args, "--uniref-version $unirefVersion" if $unirefVersion; # For families only
if ($pfam or $ipro) {
    push @args, "-max-sequence $maxFullFamily" if $maxFullFamily;
    push @args, "-fraction $fraction" if $fraction;
}

my $taxOpt = $taxSearch ? ("--tax-search \"$taxSearch\"" . ($taxSearchInvert ? " --tax-search-invert" : "")) : "";

push @args, "-blast-file $outputDir/blastfinal.tab";
push @args, "-query-file $queryFile";
push @args, "-max-results $maxBlastResults" if $maxBlastResults;
push @args, "-exclude-fragments" if $excludeFragments;
push @args, $taxOpt if $taxOpt;
push @args, "--blast-uniref-version $blastUnirefVersion" if $blastUnirefVersion;


$B = $S->getBuilder();
$B->dependency(0, $initBlastJobId); 
$B->resource(1, 1, "5gb");
addModule($B, "module load $efiEstMod");
addModule($B, "module load $efiDbMod");
$B->addAction("cd $outputDir");
$B->addAction("$efiEstTools/get_sequences_option_a.pl " . join(" ", @args));

{
    my $taxOutputFile = "$outputDir/tax.json";
    my $sourceFileArg = "--accession-file $accOutFile";
    my $useUnirefArg = "--use-uniref" . ($blastUnirefVersion ? " --uniref-version $blastUnirefVersion" : "");
    $B->addAction("$efiEstTools/get_taxonomy.pl --output-file $taxOutputFile $sourceFileArg --config $configFile $useUnirefArg"); # Remove the legacy after summer 2022
}

$B->jobName("${jobNamePrefix}get_seq_meta");
$B->renderToFile(getRenderFilePath("$scriptDir/get_sequences.sh"));

chomp($submitResult = $S->submit("$scriptDir/get_sequences.sh"));
print "get_sequences job is:\n $submitResult\n";
my $getSeqJobId = getJobId($submitResult);
push @jobIds, $getSeqJobId;



#if multiplexing is on, run an initial cdhit to get a reduced set of "more" unique sequences
#if not, just copy allsequences.fa to sequences.fa so next part of program is set up right
$B = $S->getBuilder();
$B->dependency(0, $getSeqJobId);
$B->resource(1, 1, "5gb");
addModule($B, "module load $efiEstMod");
addModule($B, "module load $efiDbMod");
#  $B->addAction("module load blast");
$B->addAction("cd $outputDir");
if ($multiplexing eq "on") {
    $B->addAction("cd-hit -d 0 -c $sim -s $lengthdif -i $allSeqFile -o $filtSeqFile");
} else {
    $B->addAction("cp $allSeqFile $filtSeqFile");
}
$B->jobName("${jobNamePrefix}multiplex");
$B->renderToFile(getRenderFilePath("$scriptDir/multiplex.sh"));

chomp($submitResult = $S->submit("$scriptDir/multiplex.sh"));
print "multiplex job is:\n $submitResult\n";
my $multiplexJobId = getJobId($submitResult);
push @jobIds, $multiplexJobId;



my $blastOutDir = "$outputDir/blast";

#break sequenes.fa into $np parts for blast
$B = $S->getBuilder();

$B->dependency(0, $multiplexJobId);
$B->resource(1, 1, "5gb");
addModule($B, "module load $efiEstMod");
$B->addAction("mkdir $blastOutDir");
$B->addAction("NP=$np");
$B->addAction("sleep 10"); # Here to avoid a syncing issue we had with the grep on the next line.
$B->addAction("NSEQ=`grep \\> $filtSeqFile | wc -l`");
$B->addAction("if [ \$NSEQ -le 50 ]; then");
$B->addAction("    NP=1");
$B->addAction("elif [ \$NSEQ -le 200 ]; then");
$B->addAction("    NP=4");
$B->addAction("elif [ \$NSEQ -le 400 ]; then");
$B->addAction("    NP=8");
$B->addAction("elif [ \$NSEQ -le 800 ]; then");
$B->addAction("    NP=12");
$B->addAction("elif [ \$NSEQ -le 1200 ]; then");
$B->addAction("    NP=16");
$B->addAction("fi");
$B->addAction("echo \"Using \$NP parts with \$NSEQ sequences\"");
$B->addAction("$efiEstTools/split_fasta.pl -parts \$NP -tmp $blastOutDir -source $filtSeqFile");
$B->jobName("${jobNamePrefix}fracfile");
$B->renderToFile(getRenderFilePath("$scriptDir/fracfile.sh"));

chomp($submitResult = $S->submit("$scriptDir/fracfile.sh"));
print "fracfile job is: $submitResult\n";
my $fracJobId = getJobId($submitResult);
push @jobIds, $fracJobId;



#make the blast database and put it into the temp directory
$B = $S->getBuilder();
$B->dependency(0, $fracJobId);
$B->resource(1, 1, "5gb");
addModule($B, "module load $efiEstMod");
addModule($B, "module load $efiDbMod");
$B->addAction("cd $outputDir");
$B->addAction("formatdb -i $filtSeqFilename -n database -p T -o T ");
$B->jobName("${jobNamePrefix}createdb");
$B->renderToFile(getRenderFilePath("$scriptDir/createdb.sh"));

chomp($submitResult = $S->submit("$scriptDir/createdb.sh"));
print "createdb job is:\n $submitResult\n";
my $createDbJobId = getJobId($submitResult);
push @jobIds, $createDbJobId;



#generate $np blast scripts for files from fracfile step
$B = $S->getBuilder();
$B->jobArray("1-$np"); # We reserve $np slots.  However, due to the new way that fracefile works, some of those may complete immediately.
$B->resource(1, 1, "10gb");
$B->dependency(0, $createDbJobId . ":" . $fracJobId);
addModule($B, "module load $efiEstMod");
$B->addAction("export BLASTDB=$outputDir");
#$B->addAction("module load blast+");
#$B->addAction("blastp -query  $blastOutDir/fracfile-{JOB_ARRAYID}.fa  -num_threads 2 -db database -gapopen 11 -gapextend 1 -comp_based_stats 2 -use_sw_tback -outfmt \"6 qseqid sseqid bitscore evalue qlen slen length qstart qend sstart send pident nident\" -num_descriptions 5000 -num_alignments 5000 -out $blastOutDir/blastout-{JOB_ARRAYID}.fa.tab -evalue $evalue");
addModule($B, "module load $efiDbMod");
if ($runSerial) {
    open my $fh, ">", "$scriptDir/blast.sh";
    print $fh "#!/bin/bash\n";
    print $fh getModuleEntry("module load $efiEstMod\n");
    print $fh "blastall -p blastp -d $outputDir/database -m 8 -e $famEvalue -b $blasthits -o $blastOutDir/blastout-\$1.fa.tab -i $blastOutDir/fracfile-\$1.fa\n";
    close $fh;
    chmod 0755, "$scriptDir/blast.sh";
    $B->addAction("echo {1..$np} | xargs -n 1 -P $np $scriptDir/blast.sh");
} else {
    $B->addAction("INFILE=\"$blastOutDir/fracfile-{JOB_ARRAYID}.fa\"");
    $B->addAction("if [[ -f \$INFILE && -s \$INFILE ]]; then");
    $B->addAction("    blastall -p blastp -i \$INFILE -d $outputDir/database -m 8 -e $famEvalue -b $blasthits -o $blastOutDir/blastout-{JOB_ARRAYID}.fa.tab");
    $B->addAction("fi");
}
$B->jobName("${jobNamePrefix}blastqsub");
$B->renderToFile(getRenderFilePath("$scriptDir/blastqsub.sh"));


chomp($submitResult = $S->submit("$scriptDir/blastqsub.sh"));
print "blast job is:\n $submitResult\n";
my $blastJobId = getJobId($submitResult);
push @jobIds, $blastJobId;




#join all the blast outputs back together
$B = $S->getBuilder();
$B->dependency(1, $blastJobId); 
$B->resource(1, 1, "5gb");
$B->addAction("cat $blastOutDir/blastout-*.tab |grep -v '#'|cut -f 1,2,3,4,12 >$outputDir/blastfinal.tab");
$B->addAction("rm  $blastOutDir/blastout-*.tab");
$B->addAction("rm  $blastOutDir/fracfile-*.fa");
$B->jobName("${jobNamePrefix}catjob");
$B->renderToFile(getRenderFilePath("$scriptDir/catjob.sh"));

chomp($submitResult = $S->submit("$scriptDir/catjob.sh"));
print "Cat job is:\n $submitResult\n";
my $catJobId = getJobId($submitResult);
push @jobIds, $catJobId;




#Remove like vs like and reverse matches
$B = $S->getBuilder();
$B->queue($memqueue);
$B->dependency(0, $catJobId); 
$B->resource(1, 4, "370gb");
addModule($B, "module load $efiEstMod");
#$B->addAction("mv $outputDir/blastfinal.tab $outputDir/unsorted.blastfinal.tab");
$B->addAction("$efiEstTools/alphabetize.pl -in $outputDir/blastfinal.tab -out $outputDir/alphabetized.blastfinal.tab -fasta $filtSeqFile");
$B->addAction("sort --parallel 4 -T $sortdir -k1,1 -k2,2 -k5,5nr -t\$\'\\t\' $outputDir/alphabetized.blastfinal.tab > $outputDir/sorted.alphabetized.blastfinal.tab");
$B->addAction("$efiEstTools/blastreduce-alpha.pl -blast $outputDir/sorted.alphabetized.blastfinal.tab -fasta $filtSeqFile -out $outputDir/unsorted.1.out");
$B->addAction("sort --parallel 4 -T $sortdir -k5,5nr -t\$\'\\t\' $outputDir/unsorted.1.out >$outputDir/1.out");
$B->jobName("${jobNamePrefix}blastreduce");
$B->renderToFile(getRenderFilePath("$scriptDir/blastreduce.sh"));

chomp($submitResult = $S->submit("$scriptDir/blastreduce.sh"));
print "Blastreduce job is:\n $submitResult\n";
my $reduceJobId = getJobId($submitResult);
push @jobIds, $reduceJobId;



#if multiplexing is on, demultiplex sequences back so all are present

$B = $S->getBuilder();
$B->queue($memqueue);
$B->dependency(0, $reduceJobId); 
$B->resource(1, 1, "5gb");
addModule($B, "module load $efiEstMod");
if ($multiplexing eq "on") {
    $B->addAction("mv $outputDir/1.out $outputDir/mux.out");
    $B->addAction("$efiEstTools/demux.pl -blastin $outputDir/mux.out -blastout $outputDir/1.out -cluster $filtSeqFile.clstr");
} else {
    $B->addAction("mv $outputDir/1.out $outputDir/mux.out");
    $B->addAction("$efiEstTools/remove_dups.pl -in $outputDir/mux.out -out $outputDir/1.out");
}
#$B->addAction("rm $outputDir/*blastfinal.tab");
#$B->addAction("rm $outputDir/mux.out");
$B->jobName("${jobNamePrefix}demux");
$B->renderToFile(getRenderFilePath("$scriptDir/demux.sh"));

chomp($submitResult = $S->submit("$scriptDir/demux.sh"));
print "Demux job is:\n $submitResult\n";
my $demuxJobId = getJobId($submitResult);
push @jobIds, $demuxJobId;



########################################################################################################################
# Compute convergence ratio, before demultiplex
#
$B = $S->getBuilder();
$B->dependency(0, $demuxJobId);
$B->resource(1, 1, "5gb");
$B->addAction("NSEQ=`grep \\> $filtSeqFile | wc -l`");
$B->addAction("$efiEstTools/calc_blast_stats.pl -edge-file $outputDir/1.out -seq-file $allSeqFile -unique-seq-file $filtSeqFile -seq-count-output $seqCountFile");
$B->jobName("${jobNamePrefix}conv_ratio");
$B->renderToFile(getRenderFilePath("$scriptDir/conv_ratio.sh"));
chomp(my $convRatioJob = $S->submit("$scriptDir/conv_ratio.sh"));
print "Convergence ratio job is:\n $convRatioJob\n";
my $convRatioJobId = getJobId($convRatioJob);
push @jobIds, $convRatioJobId;


my ($smallWidth, $smallHeight) = (700, 315);
my $evalueFile = "$outputDir/evalue.tab";
#create information for R to make graphs and then have R make them
$B = $S->getBuilder();
$B->setScriptAbortOnError(0); # don't abort on error
$B->queue($memqueue);
$B->dependency(0, $demuxJobId); 
$B->resource(1, 1, "100gb");
$B->mailEnd();
addModule($B, "module load $efiEstMod");
addModule($B, "module load $efiDbMod");
addModule($B, "module load $gdMod");
$B->addAction("mkdir $outputDir/rdata");
$B->addAction("$efiEstTools/Rgraphs.pl -blastout $outputDir/1.out -rdata  $outputDir/rdata -edges  $outputDir/edge.tab -fasta  $allSeqFile -length  $outputDir/length.tab -incfrac $incfrac -evalue-file $evalueFile");
$B->addAction("FIRST=`ls $outputDir/rdata/perid*| head -1`");
$B->addAction("FIRST=`head -1 \$FIRST`");
$B->addAction("LAST=`ls $outputDir/rdata/perid*| tail -1`");
$B->addAction("LAST=`head -1 \$LAST`");
$B->addAction("MAXALIGN=`head -1 $outputDir/rdata/maxyal`");
$B->addAction("Rscript $efiEstTools/Rgraphs/quart-align.r legacy $outputDir/rdata $outputDir/alignment_length.png \$FIRST \$LAST \$MAXALIGN $jobId");
$B->addAction("Rscript $efiEstTools/Rgraphs/quart-align.r legacy $outputDir/rdata $outputDir/alignment_length_sm.png \$FIRST \$LAST \$MAXALIGN $jobId $smallWidth $smallHeight");
$B->addAction("Rscript $efiEstTools/Rgraphs/quart-perid.r legacy $outputDir/rdata $outputDir/percent_identity.png \$FIRST \$LAST $jobId");
$B->addAction("Rscript $efiEstTools/Rgraphs/quart-perid.r legacy $outputDir/rdata $outputDir/percent_identity_sm.png \$FIRST \$LAST $jobId $smallWidth $smallHeight");
$B->addAction("Rscript $efiEstTools/Rgraphs/hist-edges.r legacy $outputDir/edge.tab $outputDir/number_of_edges.png $jobId");
$B->addAction("Rscript $efiEstTools/Rgraphs/hist-edges.r legacy $outputDir/edge.tab $outputDir/number_of_edges_sm.png $jobId $smallWidth $smallHeight");
my $lenHistText = "\" \"";
$B->addAction("Rscript $efiEstTools/Rgraphs/hist-length.r legacy $outputDir/length.tab $outputDir/length_histogram.png $jobId $lenHistText");
$B->addAction("Rscript $efiEstTools/Rgraphs/hist-length.r legacy $outputDir/length.tab $outputDir/length_histogram_sm.png $jobId $lenHistText $smallWidth $smallHeight");
$B->addAction("touch  $outputDir/1.out.completed");
$B->jobName("${jobNamePrefix}graphs");
$B->renderToFile(getRenderFilePath("$scriptDir/graphs.sh"));

chomp($submitResult = $S->submit("$scriptDir/graphs.sh"));
print "Graph job is:\n $submitResult\n";
my $graphJobId = getJobId($submitResult);
push @jobIds, $graphJobId;


if ($removeTempFiles) {
    $B = $S->getBuilder();
    $B->dependency(0, $graphJobId); 
    $B->resource(1, 1, "5gb");
    $B->addAction("rm -rf $outputDir/rdata");
    $B->addAction("rm -rf $outputDir/blast");
    $B->addAction("rm -f $outputDir/blastfinal.tab");
    $B->addAction("rm -f $outputDir/alphabetized.blastfinal.tab");
    $B->addAction("rm -f $outputDir/database.*");
    $B->addAction("rm -f $outputDir/initblast.out");
    $B->addAction("rm -f $outputDir/sorted.alphabetized.blastfinal.tab");
    $B->addAction("rm -f $outputDir/unsorted.1.out");
    #$B->addAction("rm -f $outputDir/struct.out");
    $B->addAction("rm -f $outputDir/formatdb.log");
    $B->addAction("rm -f $outputDir/mux.out");
    $B->addAction("rm -f $filtSeqFile.*");
    $B->addAction("rm $outputDir/sequences.fa.clstr");
    $B->jobName("${jobNamePrefix}cleanup");
    $B->renderToFile(getRenderFilePath("$scriptDir/cleanup.sh"));
    my $cleanupJob = $S->submit("$scriptDir/cleanup.sh");
    my $cleanupJobId = getJobId($submitResult);
    push @jobIds, $cleanupJobId;
}

print "All job IDs:\n" . join(",", @jobIds) . "\n";


sub getJobId {
    my $submitResult = shift;
    my @parts = split /\./, $submitResult;
    return $parts[0];
}


sub getRenderFilePath {
    if (not $runSerial) {
        return $_[0];
    } else {
        (my $fname = $_[0]) =~ s%^.*?([^/]+)\.sh$%$1%;
        return ($runSerial, "#\n#\n#\n#\n#$fname");
    }
}


sub initSerialScript {
    my $B = shift;

    open my $fh, ">", $runSerial or die "Unable to write to serial-script $runSerial: $!";
    print $fh "#!/bin/bash\n";
    close $fh;

    my @envScripts = split(m/,/, ($envScripts//""));
    map { $B->addAction("source $_") } @envScripts;

    chmod 0755, $runSerial;
}


sub addModule {
    my $B = shift;
    my $moduleStr = shift;
    $B->addAction($moduleStr) if $useModuleSystem;
}

sub getModuleEntry  {
    my $moduleStr = shift;
    return $useModuleSystem ? $moduleStr : "";
}

