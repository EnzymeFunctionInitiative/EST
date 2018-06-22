#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

use FindBin;
use File::Basename;
use Getopt::Long;
use EFI::SchedulerApi;
use EFI::Util qw(usesSlurm getLmod);
use EFI::Config;

use lib $FindBin::Bin . "/lib";
use BlastUtil;


$result = GetOptions(
    "seq=s"             => \$seq,
    "tmp|tmpdir=s"      => \$tmpdir,
    "evalue=s"          => \$famEvalue, # Due to the way the front-end is implemented, the -evalue parameter now is used for (optional) family input BLASTs.
    "blast-evalue=s"    => \$evalue,
    "multiplexing=s"    => \$multiplexing,
    "lengthdif=f"       => \$lengthdif,
    "sim=f"             => \$sim,
    "np=i"              => \$np,
    "blasthits=i"       => \$blasthits,
    "queue=s"           => \$queue,
    "memqueue=s"        => \$memqueue,
    "nresults=i"        => \$nresults,
    "seq-count-file=s"  => \$seqCountFile,
    "ipro=s"            => \$ipro,
    "pfam=s"            => \$pfam,
    "uniref-version=s"  => \$unirefVersion,
    "uniref-expand"     => \$unirefExpand,  # expand to include all homologues of UniRef seed sequences that are provided.
    "fraction=i"        => \$fraction,
    "maxsequence=s"     => \$maxsequence,
    "oldgraphs"         => \$LegacyGraphs,  # use the old graphing code
    "conv-ratio-file=s" => \$convRatioFile,
    "job-id=i"          => \$jobId,
    "remove-temp"       => \$removeTempFiles, # add this flag to remove temp files
    "scheduler=s"       => \$scheduler,     # to set the scheduler to slurm
    "dryrun"            => \$dryrun,        # to print all job scripts to STDOUT and not execute the job
    "oldapps"           => \$oldapps,       # to module load oldapps for biocluster2 testing
    "config=s"          => \$configFile,    # new-style config file
);

die "Environment variables not set properly: missing EFIDB variable" if not exists $ENV{EFIDB};

my $efiEstTools = $ENV{EFIEST};
my $efiEstMod = $ENV{EFIESTMOD};
my $efiDbMod = $ENV{EFIDBMOD};
my $data_files = $ENV{EFIDBPATH};
my $dbVer = $ENV{EFIDB};

if (not $configFile or not -f $configFile) {
    $configFile = $ENV{EFICONFIG};
}

die "-config file argument is required" if not -f $configFile;


die "-tmpdir argument is required" if not $tmpdir;

my $baseOutputDir = $ENV{PWD};
my $outputDir = "$baseOutputDir/$tmpdir";

print "db is: $dbVer\n";
mkdir $outputDir or die "Could not make directory $outputDir\n" if not -d $outputDir;

my $blastDb = "$data_files/combined.fasta";
my $perpass = 1000;
my $incfrac = 0.95;
my $maxhits = 5000;
my $sortdir = '/scratch';

if (not defined $evalue and defined $famEvalue) {
    $evalue = $famEvalue;
}

unless(defined $evalue){
    print "-evalue not specified, using default of 5\n";
    $evalue="1e-5";
}else{
    if( $evalue =~ /^\d+$/ ) {
        $evalue="1e-$evalue";
    }
}

if (not defined $famEvalue) {
    $famEvalue = $evalue;
}
$famEvalue = "1e-$famEvalue" if $famEvalue =~ /^\d+$/;

#defaults and error checking for multiplexing
if($multiplexing eq "on"){
    if(defined $lengthdif){
        unless($lengthdif=~/\d+(\.\d)?/){
            die "lengthdif must be in a format like 0.9d\n";
        }
    }else{
        $lengthdif=1;
    }
    if(defined $sim){
        unless($sim=~/\d+(\.\d)?/){
            die "sim must be in a format like 0.9c\n";
        }   
    }else{
        $sim=1;
    }
}elsif(!(defined $multiplexing)){
    $multiplexing="on";
    if(defined $lengthdif){
        unless($lengthdif=~/\d+(\.\d)?/){
            die "lengthdif must be in a format like 0.9a\n";
        }
    }else{
        $lengthdif=1;
    }
    if(defined $sim){
        unless($sim=~/\d+(\.\d)?/){
            die "sim must be in a format like 0.9b\n";
        }   
    }else{
        $sim=1;
    }
}else{
    die "valid variables for multiplexing are either on or off\n";
}

#you also have to specify the number of processors for blast
unless(defined $np){
    die "You must spedify the -np variable\n";
}

unless(defined $blasthits){
    $blasthits=1000000;  
}

#default queues
unless(defined $queue){
    print "-queue not specified, using default\n";
    $queue="efi";
}
unless(defined $memqueue){
    print "-memqueue not specifiied, using default\n";
    $memqueue="efi";
}

$seqCountFile = "$outputDir/acc_counts.txt" if not $seqCountFile;


# Set up the scheduler API so we can work with Torque or Slurm.
my $schedType = "torque";
$schedType = "slurm" if (defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm());
my $usesSlurm = $schedType eq "slurm";
if (defined($oldapps)) {
    $oldapps = $usesSlurm;
} else {
    $oldapps = 0;
}

# Defaults for fraction of sequences to fetch
if (defined $fraction and $fraction !~ /^\d+$/ and $fraction <= 0) {
    die "if fraction is defined, it must be greater than zero\n";
} elsif (not defined $fraction) {
    $fraction = 1;
}

my $pythonMod = getLmod("Python/2", "Python");
my $gdMod = getLmod("GD.*Perl", "GD");
my $perlMod = "Perl";
my $rMod = "R";


my $logDir = "$baseOutputDir/log";
mkdir $logDir;
$logDir = "" if not -d $logDir;
my %schedArgs = (type => $schedType, queue => $queue, resource => [1, 1, "35gb"], dryrun => $dryrun);
$schedArgs{output_base_dirpath} = $logDir if $logDir;
my $S = new EFI::SchedulerApi(%schedArgs);

my $scriptDir = "$baseOutputDir/scripts";
mkdir $scriptDir;
$scriptDir = $outputDir if not -d $scriptDir;

$maxsequence = 0 if not $maxsequence;

my $jobNamePrefix = $jobId ? $jobId . "_" : ""; 

my $queryFile = "$outputDir/query.fa";
my $allSeqFilename = "allsequences.fa";
my $allSeqFile = "$outputDir/$allSeqFilename";
my $metadataFile = "$outputDir/" . EFI::Config::FASTA_META_FILENAME;

BlastUtil::save_input_sequence($queryFile, $seq);

print "\nBlast for similar sequences and sort based off bitscore\n";

my $B = $S->getBuilder();

$B->setScriptAbortOnError(0); # Disable SLURM aborting on errors, since we want to catch the BLAST error and report it to the user nicely
$B->resource(1, 1, "50gb");
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
$B->addAction("cd $outputDir");
$B->addAction("blastall -p blastp -i $outputDir/query.fa -d $blastDb -m 8 -e $evalue -b $nresults -o $outputDir/initblast.out");
$B->addAction("OUT=\$?");
$B->addAction("if [ \$OUT -ne 0 ]; then");
$B->addAction("    echo \"BLAST failed; likely due to file format.\"");
$B->addAction("    echo $OUT > $outputDir/1.out.failed");
$B->addAction("    exit 1");
$B->addAction("fi");
$B->addAction("cat $outputDir/initblast.out |grep -v '#'|cut -f 1,2,3,4,12 |sort -k5,5nr >$outputDir/blastfinal.tab");
$B->addAction("SZ=`stat -c%s $outputDir/blastfinal.tab`");
$B->addAction("if [[ \$SZ == 0 ]]; then");
$B->addAction("    echo \"BLAST Failed. Check input sequence.\"");
$B->addAction("    touch $outputDir/1.out.failed");
$B->addAction("    exit 1");
$B->addAction("fi");
#$B->addAction("rm $outputDir/initblast.out");
#$B->addAction("$efiEstTools/getannotations.pl $userdat -out $outputDir/struct.out -fasta $allSeqFile");
$B->jobName("${jobNamePrefix}blasthits_initial_blast");
$B->renderToFile("$scriptDir/blasthits_initial_blast.sh");

$initblastjob = $S->submit("$scriptDir/blasthits_initial_blast.sh");
chomp $initblastjob;
print "initial blast job is:\n $initblastjob\n";
@initblastjobline=split /\./, $initblastjob;



$B = $S->getBuilder();
$B->dependency(0, @initblastjobline[0]); 
$B->resource(1, 1, "5gb");
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
$B->addAction("cd $outputDir");
$B->addAction("$efiEstTools/blasthits-getmatches.pl -blastfile $outputDir/blastfinal.tab -accessions $outputDir/accessions.txt -max $nresults");
$B->addAction("$efiEstTools/blasthits-write-metadata.pl -accession $outputDir/accessions.txt -meta-file $metadataFile -sequence \"$seq\"");
$B->jobName("${jobNamePrefix}blasthits_getmatches");
$B->renderToFile("$scriptDir/blasthits_getmatches.sh");

$getmatchesjob = $S->submit("$scriptDir/blasthits_getmatches.sh");
chomp $getmatchesjob;
print "getmatches job is:\n $getmatchesjob\n";
@getmatchesjobline=split /\./, $getmatchesjob;

my $depId = $getmatchesjobline[0];


$B = $S->getBuilder();
$B->dependency(0, $depId);
$B->resource(1, 1, "5gb");
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
$B->addAction("cd $outputDir");
$B->addAction("blasthits-createfasta.pl -fasta allsequences.fa -accessions accessions.txt -seq-count-file $seqCountFile");

$B->jobName("${jobNamePrefix}blasthits_createfasta");
$B->renderToFile("$scriptDir/blasthits_createfasta.sh");

$createfastajob = $S->submit("$scriptDir/blasthits_createfasta.sh");
chomp $createfastajob;
print "createfasta job is:\n $createfastajob\n";
@createfastajobline=split /\./, $createfastajob;

$depId = $createfastajobline[0];


# Get IDs from the family if it is specified.
if ($pfam or $ipro) {

    my $famOpt = "";
    $famOpt .= " -pfam $pfam" if $pfam;
    $famOpt .= " -ipro $ipro" if $ipro;

    my $seqCountFileOption = "";
    if ($seqCountFile) {
        $seqCountFileOption = "-seq-count-file $seqCountFile";
    }

    my $unirefOption = $unirefVersion ? "-uniref-version $unirefVersion" : "";
    my $unirefExpandOption = $unirefExpand ? "-uniref-expand" : "";

    $B = $S->getBuilder();
    $B->resource(1, 1, "5gb");
    $B->dependency(0, $depId);
    $B->addAction("module load $efiEstMod");
    $B->addAction("module load $efiDbMod");
    $B->addAction("cd $outputDir");
    $B->addAction("$efiEstTools/getsequence-domain.pl -domain off $famOpt -out allsequences.fa -fraction $fraction $seqCountFileOption $unirefOption $unirefExpandOption -accession-output $outputDir/accessions.txt -maxsequence $maxsequence -config=$configFile -use-option-a-settings -meta-file $metadataFile");
    $B->jobName("${jobNamePrefix}blasthits_getfamilyids");
    $B->renderToFile("$scriptDir/blasthits_getfamilyids.sh");
    
    my $getFamJob = $S->submit("$scriptDir/blasthits_getfamilyids.sh");
    chomp $getFamJob;
    print "getfamilyids job is:\n $getFamJob\n";
    my @getFamJobLine =split /\./, $getFamJob;
    
    $depId = $getFamJobLine[0];
}


my $seqLength = length($seq);
$B = $S->getBuilder();
$B->dependency(0, $depId);
$B->resource(1, 1, "5gb");
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
$B->addAction("cd $outputDir");
$B->addAction("cat $queryFile >> $allSeqFile");
$B->addAction("merge-attributes.pl -meta-file $metadataFile");
$B->addAction("getannotations.pl -out $outputDir/struct.out -fasta $allSeqFile -meta-file $metadataFile -config=$configFile");
$B->jobName("${jobNamePrefix}blasthits_getannotations");
$B->renderToFile("$scriptDir/blasthits_getannotations.sh");

$annotationjob = $S->submit("$scriptDir/blasthits_getannotations.sh");
chomp $annotationjob;
print "annotation job is:\n $annotationjob\n";
@annotationjobline=split /\./, $annotationjob;



#if multiplexing is on, run an initial cdhit to get a reduced set of "more" unique sequences
#if not, just copy allsequences.fa to sequences.fa so next part of program is set up right
$B = $S->getBuilder();
$B->dependency(0, $depId);
$B->resource(1, 1, "5gb");
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
#  $B->addAction("module load blast");
$B->addAction("cd $outputDir");
if($multiplexing eq "on"){
    $B->addAction("cd-hit -c $sim -s $lengthdif -i $allSeqFile -o $outputDir/sequences.fa");
}else{
    $B->addAction("cp $allSeqFile $outputDir/sequences.fa");
}
$B->jobName("${jobNamePrefix}blasthits_multiplex");
$B->renderToFile("$scriptDir/blasthits_multiplex.sh");

$muxjob = $S->submit("$scriptDir/blasthits_multiplex.sh");
chomp $muxjob;
print "multiplex job is:\n $muxjob\n";
@muxjobline=split /\./, $muxjob;



my $blastOutDir = "$outputDir/blast";

#break sequenes.fa into $np parts for blast
$B = $S->getBuilder();

$B->dependency(0, @muxjobline[0]); 
$B->resource(1, 1, "5gb");
$B->addAction("module load $efiEstMod");
$B->addAction("mkdir $blastOutDir");
$B->addAction("NP=$np");
$B->addAction("NSEQ=`grep \\> $outputDir/sequences.fa | wc -l`");
$B->addAction("if [ \$NSEQ -le 50 ]; then");
$B->addAction("    NP=1");
$B->addAction("elif [ \$NSEQ -le 200 ]; then");
$B->addAction("    NP=4");
$B->addAction("elif [ \$NSEQ -le 400]; then");
$B->addAction("    NP=8");
$B->addAction("elif [ \$NSEQ -le 800]; then");
$B->addAction("    NP=12");
$B->addAction("elif [ \$NSEQ -le 1200]; then");
$B->addAction("    NP=16");
$B->addAction("fi");
$B->addAction("$efiEstTools/splitfasta.pl -parts \$NP -tmp $blastOutDir -source $outputDir/sequences.fa");
$B->jobName("${jobNamePrefix}blasthits_fracfile");
$B->renderToFile("$scriptDir/blasthits_fracfile.sh");

$fracfilejob = $S->submit("$scriptDir/blasthits_fracfile.sh");
chomp $fracfilejob;
print "fracfile job is: $fracfilejob\n";
@fracfilejobline=split /\./, $fracfilejob;



#make the blast database and put it into the temp directory
$B = $S->getBuilder();
$B->dependency(0, @muxjobline[0]);
$B->resource(1, 1, "5gb");
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
$B->addAction("cd $outputDir");
$B->addAction("formatdb -i sequences.fa -n database -p T -o T ");
$B->jobName("${jobNamePrefix}blasthits_createdb");
$B->renderToFile("$scriptDir/blasthits_createdb.sh");

$createdbjob = $S->submit("$scriptDir/blasthits_createdb.sh");
chomp $createdbjob;
print "createdb job is:\n $createdbjob\n";
@createdbjobline=split /\./, $createdbjob;



#generate $np blast scripts for files from fracfile step
$B = $S->getBuilder();
$B->jobArray("1-$np"); # We reserve $np slots.  However, due to the new way that fracefile works, some of those may complete immediately.
$B->resource(1, 1, "5gb");
$B->dependency(0, @createdbjobline[0] . ":" . @fracfilejobline[0]);
$B->addAction("module load $efiEstMod");
$B->addAction("export BLASTDB=$outputDir");
#$B->addAction("module load blast+");
#$B->addAction("blastp -query  $blastOutDir/fracfile-{JOB_ARRAYID}.fa  -num_threads 2 -db database -gapopen 11 -gapextend 1 -comp_based_stats 2 -use_sw_tback -outfmt \"6 qseqid sseqid bitscore evalue qlen slen length qstart qend sstart send pident nident\" -num_descriptions 5000 -num_alignments 5000 -out $blastOutDir/blastout-{JOB_ARRAYID}.fa.tab -evalue $evalue");
$B->addAction("module load $efiDbMod");
$B->addAction("INFILE=\"$blastOutDir/fracfile-{JOB_ARRAYID}.fa\"");
$B->addAction("if [[ -f \$INFILE && -s \$INFILE ]]; then");
$B->addAction("    blastall -p blastp -i \$INFILE -d $outputDir/database -m 8 -e $famEvalue -b $blasthits -o $blastOutDir/blastout-{JOB_ARRAYID}.fa.tab");
$B->addAction("fi");
$B->jobName("${jobNamePrefix}blasthits_blast-qsub");
$B->renderToFile("$scriptDir/blasthits_blast-qsub.sh");


$blastjob = $S->submit("$scriptDir/blasthits_blast-qsub.sh");
chomp $blastjob;
print "blast job is:\n $blastjob\n";
@blastjobline=split /\./, $blastjob;




#join all the blast outputs back together
$B = $S->getBuilder();
$B->dependency(1, @blastjobline[0]); 
$B->resource(1, 1, "5gb");
$B->addAction("cat $blastOutDir/blastout-*.tab |grep -v '#'|cut -f 1,2,3,4,12 >$outputDir/blastfinal.tab");
$B->addAction("rm  $blastOutDir/blastout-*.tab");
$B->addAction("rm  $blastOutDir/fracfile-*.fa");
$B->jobName("${jobNamePrefix}blasthits_catjob");
$B->renderToFile("$scriptDir/blasthits_catjob.sh");

$catjob = $S->submit("$scriptDir/blasthits_catjob.sh");
chomp $catjob;
print "Cat job is:\n $catjob\n";
@catjobline=split /\./, $catjob;




#Remove like vs like and reverse matches
$B = $S->getBuilder();
$B->queue($memqueue);
$B->dependency(0, @catjobline[0]); 
$B->resource(1, 1, "35gb");
$B->addAction("module load $efiEstMod");
#$B->addAction("mv $outputDir/blastfinal.tab $outputDir/unsorted.blastfinal.tab");
$B->addAction("$efiEstTools/alphabetize.pl -in $outputDir/blastfinal.tab -out $outputDir/alphabetized.blastfinal.tab -fasta $outputDir/sequences.fa");
$B->addAction("sort -T $sortdir -k1,1 -k2,2 -k5,5nr -t\$\'\\t\' $outputDir/alphabetized.blastfinal.tab > $outputDir/sorted.alphabetized.blastfinal.tab");
$B->addAction("$efiEstTools/blastreduce-alpha.pl -blast $outputDir/sorted.alphabetized.blastfinal.tab -fasta $outputDir/sequences.fa -out $outputDir/unsorted.1.out");
$B->addAction("sort -T $sortdir -k5,5nr -t\$\'\\t\' $outputDir/unsorted.1.out >$outputDir/1.out");
$B->jobName("${jobNamePrefix}blasthits_blastreduce");
$B->renderToFile("$scriptDir/blasthits_blastreduce.sh");

$blastreducejob = $S->submit("$scriptDir/blasthits_blastreduce.sh");
chomp $blastreducejob;
print "Blastreduce job is:\n $blastreducejob\n";
@blastreducejobline=split /\./, $blastreducejob;



#if multiplexing is on, demultiplex sequences back so all are present

$B = $S->getBuilder();
$B->queue($memqueue);
$B->dependency(0, @blastreducejobline[0]); 
$B->resource(1, 1, "5gb");
$B->addAction("module load $efiEstMod");
if($multiplexing eq "on"){
    $B->addAction("mv $outputDir/1.out $outputDir/mux.out");
    $B->addAction("$efiEstTools/demux.pl -blastin $outputDir/mux.out -blastout $outputDir/1.out -cluster $outputDir/sequences.fa.clstr");
}else{
    $B->addAction("mv $outputDir/1.out $outputDir/mux.out");
    $B->addAction("$efiEstTools/removedups.pl -in $outputDir/mux.out -out $outputDir/1.out");
}
#$B->addAction("rm $outputDir/*blastfinal.tab");
#$B->addAction("rm $outputDir/mux.out");
$B->jobName("${jobNamePrefix}blasthits_demux");
$B->renderToFile("$scriptDir/blasthits_demux.sh");

$demuxjob = $S->submit("$scriptDir/blasthits_demux.sh");
chomp $demuxjob;
print "Demux job is:\n $demuxjob\n";
@demuxjobline=split /\./, $demuxjob;




my $evalueFile = "$outputDir/evalue.tab";
#create information for R to make graphs and then have R make them
$B = $S->getBuilder();
$B->setScriptAbortOnError(0); # don't abort on error
$B->queue($memqueue);
$B->dependency(0, @demuxjobline[0]); 
$B->resource(1, 1, "20gb");
$B->mailEnd();
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
$B->addAction("module load $gdMod");
$B->addAction("module load $perlMod");
$B->addAction("module load $rMod");
$B->addAction("mkdir $outputDir/rdata");
$B->addAction("$efiEstTools/Rgraphs.pl -blastout $outputDir/1.out -rdata  $outputDir/rdata -edges  $outputDir/edge.tab -fasta  $allSeqFile -length  $outputDir/length.tab -incfrac $incfrac -evalue-file $evalueFile");
$B->addAction("FIRST=`ls $outputDir/rdata/perid*| head -1`");
$B->addAction("FIRST=`head -1 \$FIRST`");
$B->addAction("LAST=`ls $outputDir/rdata/perid*| tail -1`");
$B->addAction("LAST=`head -1 \$LAST`");
$B->addAction("MAXALIGN=`head -1 $outputDir/rdata/maxyal`");
$B->addAction("Rscript $efiEstTools/quart-align.r $outputDir/rdata $outputDir/alignment_length.png \$FIRST \$LAST \$MAXALIGN");
$B->addAction("Rscript $efiEstTools/quart-perid.r $outputDir/rdata $outputDir/percent_identity.png \$FIRST \$LAST");
$B->addAction("Rscript $efiEstTools/hist-length.r  $outputDir/length.tab  $outputDir/length_histogram.png");
$B->addAction("Rscript $efiEstTools/hist-edges.r $outputDir/edge.tab $outputDir/number_of_edges.png");
$B->addAction("touch  $outputDir/1.out.completed");
#$B->addAction("rm $outputDir/alphabetized.blastfinal.tab $outputDir/blastfinal.tab $outputDir/sorted.alphabetized.blastfinal.tab $outputDir/unsorted.1.out");
$B->jobName("${jobNamePrefix}blasthits_graphs");
$B->renderToFile("$scriptDir/blasthits_graphs.sh");

$graphjob = $S->submit("$scriptDir/blasthits_graphs.sh");
chomp $graphjob;
print "Graph job is:\n $graphjob\n";


if ($removeTempFiles) {
    $B = $S->getBuilder();
    $B->resource(1, 1, "5gb");
    $B->addAction("rm -rf $outputDir/rdata");
    $B->addAction("rm -rf $outputDir/blast");
    $B->addAction("rm -f $outputDir/blastfinal.tab");
    $B->addAction("rm -f $outputDir/alphabetized.blastfinal.tab");
    $B->addAction("rm -f $outputDir/database.*");
    $B->addAction("rm -f $outputDir/initblast.out");
    $B->addAction("rm -f $outputDir/sorted.alphabetized.blastfinal.tab");
    $B->addAction("rm -f $outputDir/unsorted.1.out");
    $B->addAction("rm -f $outputDir/struct.out");
    $B->addAction("rm -f $outputDir/formatdb.log");
    $B->addAction("rm -f $outputDir/mux.out");
    $B->addAction("rm -f $outputDir/sequences.fa.*");
    $B->jobName("${jobNamePrefix}blasthits_cleanup");
    $B->renderToFile("$scriptDir/blasthits_cleanup.sh");
    my $cleanupJob = $S->submit("$scriptDir/blasthits_cleanup.sh");
}


