#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}

#this program will analyze data from a folder created in the generatedata step, the most important parts being the 1.out and struct.out files

#this program creates scripts and submits them on clusters with torque schedulers
#filterblast.pl            Filters 1.out files to remove unwanted information, creates 2.out file
#xgmml_100_create.pl        Creates a truely 100% xgmml (all nodes and edges) from stuct.out and 2.out files
#xgmml_create_al.pl        Creates xgmml repnode networks from struct.out, 2.out, and cdit output
#stats.pl            Displays number of edges and nodes in each xgmml


use strict;
use warnings;

use FindBin;
use Getopt::Long qw(:config pass_through);
use EFI::SchedulerApi;
use EFI::Util qw(usesSlurm);
use EFI::Config qw(cluster_configure);

use lib "$FindBin::Bin/lib";
use Constants;


my ($filter, $minval, $queue, $resultsDirName, $jobDir, $maxlen, $minlen, $title, $maxfull, $jobId, $generateJobId, $lengthOverlap,
    $customClusterFile, $customClusterDir, $scheduler, $dryrun, $configFile, $parentId, $parentDir, $cdhitUseAccurateAlgo,
    $cdhitBandwidth, $cdhitDefaultWord, $cdhitOpt, $includeSeqs, $includeAllSeqs, $unirefVersion, $useAnnoSpec, $useMinEdgeAttr,
    $computeNc, $noRepNodeNetworks, $cleanup, $taxSearch, $taxSearchHash, $removeFragments, $debug, $analysisDir, $runSerial, $envScripts, $useNoModules,
    $transferFile);
my $result = GetOptions(
    "filter=s"              => \$filter,
    "minval=s"              => \$minval,
    "queue=s"               => \$queue,
    "job-dir=s"             => \$jobDir, # generate job dir
    "results-dir-name=s"    => \$resultsDirName, # the results sub-dir within generate job dir (e.g. output)
    "output-path=s"         => \$analysisDir, # full path of output directory
    "maxlen=i"              => \$maxlen,
    "minlen=i"              => \$minlen,
    "title=s"               => \$title,
    "maxfull=i"             => \$maxfull,
    "job-id=s"              => \$jobId,
    "generate-job-id=s"     => \$generateJobId,
    "lengthdif=i"           => \$lengthOverlap,
    "custom-cluster-file=s" => \$customClusterFile,
    "custom-cluster-dir=s"  => \$customClusterDir,
    "parent-id=s"           => \$parentId,
    "parent-dir=s"          => \$parentDir,
    "cdhit-high-accuracy"   => \$cdhitUseAccurateAlgo,  # Get rid of this?
    "cdhit-bandwidth=i"     => \$cdhitBandwidth,        # Get rid of this?
    "cdhit-default-word"    => \$cdhitDefaultWord,      # Get rid of this?
    "cdhit-opt=s"           => \$cdhitOpt,
    "include-sequences"     => \$includeSeqs,   # true to include sequences in the XGMML files
    "include-all-sequences" => \$includeAllSeqs,   # true to include sequences in the XGMML files
    "uniref-version=s"      => \$unirefVersion,
    "use-anno-spec"         => \$useAnnoSpec,
    "use-min-edge-attr"     => \$useMinEdgeAttr,
    "compute-nc"            => \$computeNc,
    "no-repnode"            => \$noRepNodeNetworks,
    "scheduler=s"           => \$scheduler,     # to set the scheduler to slurm 
    "dryrun"                => \$dryrun,        # to print all job scripts to STDOUT and not execute the job
    "config"                => \$configFile,        # config file path, if not given will look for EFI_CONFIG env var
    "keep-xgmml"            => \$cleanup,
    "tax-search=s"          => \$taxSearch,
    "tax-search-hash=s"     => \$taxSearchHash,
    "remove-fragments"      => \$removeFragments,
    "serial-script=s"       => \$runSerial,     # run in serial mode
    "env-scripts=s"         => \$envScripts,
    "no-modules"            => \$useNoModules,
    "debug"                 => \$debug,
    "zip-transfer=s"        => \$transferFile,
);

die "The efiest and efidb environments must be loaded in order to run $0" if not $ENV{EFI_EST} or not $ENV{EFI_EST_MOD} or not $ENV{EFI_DB_MOD};
die "The Perl environment must be loaded in order to run $0" if $ENV{LOADEDMODULES} !~ m/\bperl\b/i; # Ensure that the Perl module is loaded (e.g. module load Perl)


my $toolpath = $ENV{EFI_EST};
my $efiEstMod = $ENV{EFI_EST_MOD};
my $efiDbMod = $ENV{EFI_DB_MOD};
(my $perlMod = $ENV{LOADEDMODULES}) =~ s/^.*\b(perl)\b.*$/$1/i;

$jobDir = $ENV{PWD} if not $jobDir;
$resultsDirName = "output" if not $resultsDirName;
my $generateDir = "$jobDir/$resultsDirName";

my $dbver = "";
if (-f "$generateDir/database_version") {
    $dbver = `head -1 $generateDir/database_version`;
    chomp $dbver;
}
if (not $dbver) {
    ($dbver = $efiDbMod) =~ s/\D//g;
}

$minlen = 0                 unless defined $minlen;
$maxlen = 50000             unless defined $maxlen;
$filter = "bit"             unless defined $filter;
$minval = 0                 unless defined $minval;
$title = "Untitled"         unless defined $title;
$queue = "efi"              unless defined $queue;
$lengthOverlap = 1          unless (defined $lengthOverlap and $lengthOverlap);
$cdhitBandwidth = ""        unless defined $cdhitBandwidth;
$cdhitDefaultWord = 0       unless defined $cdhitDefaultWord;
$cdhitOpt = ""              unless defined $cdhitOpt;
$includeSeqs = 0            unless defined $includeSeqs;
$includeAllSeqs = 0         unless defined $includeAllSeqs;

$cleanup = not $cleanup;
$cdhitUseAccurateAlgo = defined $cdhitUseAccurateAlgo ? 1 : 0;
$useAnnoSpec = defined $useAnnoSpec ? 1 : 0;
$useMinEdgeAttr = defined $useMinEdgeAttr ? 1 : 0;
$computeNc = defined $computeNc ? 1 : 0;
$debug = 0 if not defined $debug;

my @jobIds;

(my $safeTitle = $title) =~ s/[^A-Za-z0-9_\-]/_/g;
$safeTitle .= "_" if $safeTitle;
$safeTitle = $generateJobId . "_" . $safeTitle if defined $generateJobId and $generateJobId;
$safeTitle .= "${taxSearchHash}_" if $taxSearchHash;

if (defined $maxfull and $maxfull !~ /^\d+$/) {
    die "maxfull must be an integer\n";
} elsif (not defined $maxfull) {
    $maxfull = 10000000;
}


if (not defined $configFile or not -f $configFile) {
    if (exists $ENV{EFI_CONFIG}) {
        $configFile = $ENV{EFI_CONFIG};
    } else {
        die "--config file parameter is not specified.  module load efiest_v2 should take care of this.";
    }
}
my $config = {};
cluster_configure($config, config_file_path => $configFile);

my $hasParent = defined $parentId and $parentId > 0 and defined $parentDir and -d $parentDir;

if ($hasParent) {
    $generateDir = $parentDir;
}

if (not $analysisDir) {
    $analysisDir = "$generateDir/$filter-$minval-$minlen-$maxlen";
    if ($customClusterDir and $customClusterFile and -f "$generateDir/$customClusterDir/$customClusterFile") {
        $analysisDir = "$generateDir/$customClusterDir";
    }
    $analysisDir .= "-$cdhitOpt" if $cdhitOpt eq "sb" or $cdhitOpt eq "est+";
    $analysisDir .= "-minn" if $useAnnoSpec;
    $analysisDir .= "-mine" if $useMinEdgeAttr;
    $analysisDir .= "-nc" if $computeNc;
    $analysisDir .= "-$taxSearchHash" if $taxSearchHash;
    $analysisDir .= "-nf" if $removeFragments;
}


my $schedType = "torque";
$schedType = "slurm" if (defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm());
my $usesSlurm = $schedType eq "slurm";

my $wordOption = ($lengthOverlap < 1 and not $cdhitDefaultWord) ? "-n 2" : "";
my $bandwidthOption = ($cdhitBandwidth and $cdhitBandwidth > 1) ? "-b $cdhitBandwidth" : "";
my $algoOption = $cdhitUseAccurateAlgo ? "-g 1" : "";
if ($cdhitOpt eq "sb") {
    $bandwidthOption = "-b 10";
    $algoOption = "-g 1";
    $wordOption = "";
} elsif ($cdhitOpt eq "est+") {
    $algoOption = "-g 1";
}

my $jobNamePrefix = ($jobId ? "${jobId}_" : "") . ($generateJobId ? "${generateJobId}_" : ""); 


my $unirefOption = "";
if ($unirefVersion) {
    $unirefOption = "-uniref-version $unirefVersion";
}

my $logDir = "$jobDir/log";
mkdir $logDir if not $dryrun;
$logDir = "" if not -d $logDir;

my $useModuleSystem = not $useNoModules;

my %schedArgs = (type => $schedType, queue => $queue, resource => [1, 1], dryrun => $dryrun);
$schedArgs{output_base_dirpath} = $logDir if $logDir;
$schedArgs{extra_path} = $config->{cluster}->{extra_path} if $config->{cluster}->{extra_path};
my $S = new EFI::SchedulerApi(%schedArgs);


my $B;

if ($runSerial) {
    $B = $S->getBuilder();
    initSerialScript($B);
} 

print "Data from runs will be saved to $analysisDir\n";

my $inputFilesDir = $generateDir;
if ($transferFile) {
    $B = $S->getBuilder();
    $B->resource(1, 1, "5gb");
    $B->addAction("unzip $transferFile -d $analysisDir/");
    $B->renderToFile(getRenderFilePath("$analysisDir/transfer.sh"));
    my $jobId = $S->submit("$analysisDir/transfer.sh", $dryrun);
    chomp($jobId);
    $jobId = getJobId($jobId);
    push @jobIds, $jobId;
    $inputFilesDir = $analysisDir;
}

my $filteredBlastFile = "$analysisDir/2.out";
my $filteredAnnoFile = "$analysisDir/struct.filtered.out";
my $evalueTableOutputFile = "$analysisDir/blast_evalue.txt";
my $userHeaderFile = "$inputFilesDir/" . EFI::Config::FASTA_META_FILENAME;
my $annoSpecFile = "$inputFilesDir/" . EFI::Config::ANNOTATION_SPEC_FILENAME;
my $evalueTableInputFile = "$inputFilesDir/blast_hits.tab"; # BLAST jobs only
my $inputResultsFile = "$inputFilesDir/1.out";
my $inputSequencesFile = "$inputFilesDir/allsequences.fa";

####################################################################################################
# RETRIEVE ANNOTATIONS (STRUCT.OUT) FOR SSN
# And for UniRef inputs, filter out UniRef cluster members that are outside the input length
# thresholds.
#

#TODO: right now if you useAnnoSpec, we actually just include the bare minimum.  In the future allow the user to determine which annotations to include.
if ($useAnnoSpec) {
    open SPEC, ">", $annoSpecFile;
    print SPEC <<ANNO;
seq_len
organism
superkingdom
description
ANNO
    close SPEC;
}

my $hasDomain = checkForDomain($inputResultsFile);

my $bcCmd = "$toolpath/bc";


my $annoSpecOption = $useAnnoSpec ? " -anno-spec-file $annoSpecFile" : "";
my $lenArgs = "-min-len $minlen -max-len $maxlen";
# Don't filter out UniRef cluster members if this is a domain job.
$lenArgs = "" if $hasDomain;
mkdir $analysisDir or die "could not make analysis folder $analysisDir (we're in $ENV{PWD})\n" if (not $dryrun and not -d $analysisDir);

# If a taxonomy search parameter has been added, then we need to filter the annotations by the taxonomy filter,
# and then come up with a list of IDs (that is a subset of what the normal 2.out file would contain).
my $analysisMetaFile = $userHeaderFile;
my $idListOption = "";

my $taxDepId;
if ($taxSearch or $removeFragments) {
    $analysisMetaFile = "$analysisDir/filtered.meta";
    my $taxSearchOption = $taxSearch ? "--tax-filter \"$taxSearch\"" : "";
    my $removeFragmentsOption = $removeFragments ? "--remove-fragments" : "";
    my $debugFlag = $debug ? "--debug" : "";
    $idListOption = "--filter-id-list $analysisDir/filtered.ids";
    $B = $S->getBuilder();
    $B->resource(1, 1, "5gb");
    addModule($B, "module load $efiEstMod");
    addModule($B, "module load $efiDbMod");
    $B->addAction("$toolpath/get_filtered_ids.pl --meta-file $userHeaderFile --filtered-meta-file $analysisMetaFile $idListOption $taxSearchOption $removeFragmentsOption --config $configFile $debugFlag");
    $B->jobName("${jobNamePrefix}get_filtered_ids");
    $B->dependency(0, $jobIds[$#jobIds]) if $transferFile;
    $B->renderToFile(getRenderFilePath("$analysisDir/get_filtered_ids.sh"));
    my $jobId = $S->submit("$analysisDir/get_filtered_ids.sh", $dryrun);
    chomp($jobId);
    $jobId = getJobId($jobId);
    push @jobIds, $jobId;
    print "ID list job is:\n$jobId\n";
    $taxDepId = $jobId;
}


$B = $S->getBuilder();
$B->dependency(0, $taxDepId) if $taxDepId;
$B->resource(1, 1, "5gb");
addModule($B, "module load $efiEstMod");
addModule($B, "module load $efiDbMod");
$B->addAction("$toolpath/get_annotations.pl -out $filteredAnnoFile $unirefOption $lenArgs --meta-file $analysisMetaFile $annoSpecOption -config=$configFile");
if (-e $evalueTableInputFile and -s $evalueTableInputFile > 0) {
    $B->addAction("$toolpath/make_blast_evalue_table.pl --input $evalueTableInputFile --meta-file $filteredAnnoFile --output $evalueTableOutputFile");
}
$B->jobName("${jobNamePrefix}get_annotations");
$B->renderToFile(getRenderFilePath("$analysisDir/get_annotations.sh"));
my $annoJobId = $S->submit("$analysisDir/get_annotations.sh", $dryrun);
chomp($annoJobId);
$annoJobId = getJobId($annoJobId);
push @jobIds, $annoJobId;
print "Annotations job is:\n$annoJobId\n";



####################################################################################################
# FILTER MAIN SEQUENCES
#

$B = $S->getBuilder();
$B->dependency(0, $annoJobId) if $annoJobId;
$B->resource(1, 1, "5gb");
addModule($B, "module load $efiEstMod");
if ($customClusterDir and $customClusterFile) {
    $B->addAction("$toolpath/filter_custom.pl -blastin $inputResultsFile -blastout $filteredBlastFile -custom-cluster-file $analysisDir/$customClusterFile");
    $B->addAction("cp $inputSequencesFile $analysisDir/sequences.fa");
} else {
    my $domMetaArg = ($unirefVersion and $hasDomain) ? "-domain-meta $filteredAnnoFile" : "";
    $B->addAction("$toolpath/filter_blast.pl -blastin $inputResultsFile -blastout $filteredBlastFile -fastain $inputSequencesFile -fastaout $analysisDir/sequences.fa -filter $filter -minval $minval -maxlen $maxlen -minlen $minlen $domMetaArg $idListOption");
}
if ($hasParent) {
    $B->addAction("cp $parentDir/*.png $generateDir/");
}

$B->jobName("${jobNamePrefix}filterblast");
$B->renderToFile(getRenderFilePath("$analysisDir/filterblast.sh"));
my $filterJobId = $S->submit("$analysisDir/filterblast.sh", $dryrun);
chomp($filterJobId);
$filterJobId = getJobId($filterJobId);
push @jobIds, $filterJobId;
print "Filterblast job is:\n$filterJobId\n";


my $xgmmlDomainArgs = $hasDomain ? "--is-domain" : "";

#submit the job for generating the full xgmml file
#since struct.out is created in the first half, the full and repnode networks can all be generated at the same time
#depends on ffilterblast

$B = $S->getBuilder();
$B->dependency(0, $filterJobId);
$B->resource(1, 1, "30gb");
addModule($B, "module load $efiEstMod");
addModule($B, "module load GD/2.73-IGB-gcc-8.2.0-Perl-5.28.1");
my $outFile = "$analysisDir/${safeTitle}full_ssn.xgmml";
my $ncFile = "$analysisDir/${safeTitle}full_ssn_nc";
my $seqsArg = $includeSeqs ? "-include-sequences" : "";
$seqsArg .= " -include-all-sequences" if $includeAllSeqs;
my $useMinArg = $useMinEdgeAttr ? "-use-min-edge-attr" : "";
$B->addAction("$toolpath/dump_connectivity.pl --input-blast $filteredBlastFile --output-map $ncFile.tab") if $computeNc;
$B->addAction("$toolpath/xgmml_100_create.pl -blast=$filteredBlastFile -fasta $analysisDir/sequences.fa -struct $filteredAnnoFile -out $outFile -title=\"$title\" -maxfull $maxfull -dbver $dbver $seqsArg $useMinArg $xgmmlDomainArgs " . (($ncFile and $computeNc) ? "--nc-map $ncFile.tab" : ""));
$B->addAction("$toolpath/make_color_ramp.pl --input $ncFile.tab --output $ncFile.png") if $computeNc;
$B->addAction("zip -j $outFile.zip $outFile");
$B->jobName("${jobNamePrefix}fullxgmml");
$B->renderToFile(getRenderFilePath("$analysisDir/fullxgmml.sh"));

#submit generate the full xgmml script, job dependences should keep it from running till blast results have been created all blast out files are combined

my $fulljob = $S->submit("$analysisDir/fullxgmml.sh", $dryrun, $schedType);
chomp($fulljob);
$fulljob = getJobId($fulljob);
push @jobIds, $fulljob;
print "Full xgmml job is:\n$fulljob\n";

#submit series of repnode network calculations
#depends on filterblast

my $depId = $fulljob;
if (not $noRepNodeNetworks) {
    $B = $S->getBuilder();
    $B->jobArray("40,45,50,55,60,65,70,75,80,85,90,95,100");
    $B->dependency(0, $filterJobId);
    $B->resource(1, 1, "30gb");
    addModule($B, "module load $efiEstMod");
    addModule($B, "module load GD/2.73-IGB-gcc-8.2.0-Perl-5.28.1");

    my $varName = "{JOB_ARRAYID}";
    my $cdhitFh;
    my $writeFn = sub { $B->addAction($_[0]); };

    if ($runSerial) {
        open $cdhitFh , ">", "$analysisDir/cdhit_subtask.sh";
        print $cdhitFh "#!/bin/bash\n";
        print $cdhitFh getModuleEntry("module load $efiEstMod\n");
        print $cdhitFh getModuleEntry("module load GD/2.73-IGB-gcc-8.2.0-Perl-5.28.1\n");
        $varName = "\$1";
        $writeFn = sub {
            $cdhitFh->print($_[0], "\n");
        };
    }

    &$writeFn("BC_CMD=$bcCmd");
    &$writeFn("export BC_CMD");
    &$writeFn("CDHIT=\$(echo \"scale=2; $varName/100\" | \$BC_CMD -l)");
    if ($cdhitOpt eq "sb" or $cdhitOpt eq "est+") {
        &$writeFn("WORDOPT=5");
        &$writeFn('if (( $(echo "$CDHIT < 0.81" | $BC_CMD -l) )); then WORDOPT=5; fi');
        &$writeFn('if (( $(echo "$CDHIT < 0.71" | $BC_CMD -l) )); then WORDOPT=4; fi');
        &$writeFn('if (( $(echo "$CDHIT < 0.61" | $BC_CMD -l) )); then WORDOPT=3; fi');
        &$writeFn('if (( $(echo "$CDHIT < 0.51" | $BC_CMD -l) )); then WORDOPT=2; fi');
        &$writeFn('echo $WORDOPT');
        $wordOption = '-n $WORDOPT';
    } else {
        $wordOption = "-n 2"; # Default option
    }
    
    my $lengthOverlapOption = "";
    if ($cdhitOpt ne "sb") {
        $lengthOverlapOption = "-s $lengthOverlap";
    }
    
    my $cdhitFile = "$analysisDir/cdhit\$CDHIT";
    &$writeFn("cd-hit $wordOption $lengthOverlapOption -i $analysisDir/sequences.fa -o $cdhitFile -c \$CDHIT -d 0 $algoOption $bandwidthOption");
    $outFile = "$analysisDir/${safeTitle}repnode-\${CDHIT}_ssn.xgmml";
    $ncFile = "";
    if ($computeNc) {
        $ncFile = "$analysisDir/${safeTitle}repnode-\${CDHIT}_ssn_nc";
        &$writeFn("$toolpath/dump_connectivity.pl --input-blast $filteredBlastFile --output-map $ncFile.tab --cdhit $cdhitFile.clstr"); 
        &$writeFn("$toolpath/make_color_ramp.pl --input $ncFile.tab --output $ncFile.png");
    }
    &$writeFn("sleep 10"); # To allow the file system to make all of the necessary writes before we read the files
    &$writeFn("$toolpath/xgmml_create_all.pl -blast $filteredBlastFile -cdhit $cdhitFile.clstr -fasta $analysisDir/sequences.fa -struct $filteredAnnoFile -out $outFile -title=\"$title\" -dbver $dbver -maxfull $maxfull $seqsArg $useMinArg $xgmmlDomainArgs " . ($ncFile ? "--nc-map $ncFile.tab" : ""));
    &$writeFn("zip -j $outFile.zip $outFile");

    if ($runSerial) {
        close $cdhitFh;
        chmod 0755, "$analysisDir/cdhit.sh";
        $B->addAction("seq 40 5 100 | xargs -n 1 -P 1 $analysisDir/cdhit.sh");
    }

    $B->jobName("${jobNamePrefix}cdhit");
    $B->renderToFile(getRenderFilePath("$analysisDir/cdhit.sh"));
    
    #submit the filter script, job dependences should keep it from running till all blast out files are combined
    my $repnodejob = $S->submit("$analysisDir/cdhit.sh", $dryrun, $schedType);
    chomp($repnodejob);
    $repnodejob = getJobId($repnodejob);
    push @jobIds, $repnodejob;
    print "Repnodes job is:\n$repnodejob\n";
    $depId = $repnodejob;
}

#test to fix dependancies
#depends on cdhit.sh
$B = $S->getBuilder();
$B->resource(1, 1, "1gb");
$B->dependency(1, $depId);
addModule($B, "module load $efiEstMod");
$B->addAction("sleep 5");
$B->jobName("${jobNamePrefix}fix");
$B->renderToFile(getRenderFilePath("$analysisDir/fix.sh"));

#submit the filter script, job dependences should keep it from running till all blast out files are combined

my $fixjob = $S->submit("$analysisDir/fix.sh", $dryrun, $schedType);
chomp($fixjob);
$fixjob = getJobId($fixjob);
push @jobIds, $fixjob;
print "Fix job is:\n$fixjob\n";

#submit series of repnode network calculations
#depends on filterblast
$B = $S->getBuilder();
$B->dependency(0, "$fulljob:$fixjob");
$B->resource(1, 1, "5gb");
#$B->dependency(0, $fulljobline[0]); 
$B->mailEnd();
addModule($B, "module load $efiEstMod");
$B->addAction("$toolpath/stats.pl -run-dir $analysisDir -out $analysisDir/stats.tab");
$B->addAction("rm $analysisDir/*.xgmml") if $cleanup;
$B->jobName("${jobNamePrefix}stats");
$B->renderToFile(getRenderFilePath("$analysisDir/stats.sh"));

#submit the filter script, job dependences should keep it from running till all blast out files are combined
my $statjob = $S->submit("$analysisDir/stats.sh", $dryrun, $schedType);
chomp($statjob);
$statjob = getJobId($statjob);
push @jobIds, $statjob;
print "Stats job is:\n$statjob\n";

print "All analysis job IDs:\n" . join(",", @jobIds), "\n";



sub checkForDomain {
    my $file = shift;

    open FILE, $file or return 0;
    my $line = <FILE>;
    close FILE;

    return 0 if not $line;
    return $line =~ m/^\S+:\d+:\d+/;
}


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


