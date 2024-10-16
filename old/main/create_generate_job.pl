#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

# This program creates bash scripts and submits them on clusters with torque schedulers, overview of steps below
#   Step 1 fetch sequences and get annotations
#       initial_import.sh       generates initial_import script that contains getsequence.pl and getannotation.pl or just getseqtaxid.pl if input was from taxid
#           getsequence.pl      grabs sequence data for input (other than taxid) submits jobs that do the following makes allsequences.fa
#           getannotations.pl   grabs annotations for input (other than taxid) creates struct.out file makes struct.out
#           getseqtaxid.pl      get sequence data and annotations based on taxid makes both struct.out and allsequences.fa
#   Step 2 reduce number of searches
#       multiplex.sh            performs a cdhit on the input 
#           cdhit is an open source tool that groups sequences based on similarity and length, unique sequences in sequences.fa
#           cdhit also creates sequences.fa.clustr for demultiplexing sequences later
#       if multiplexing is turned off, then this just copies allsequences.fa to sequences.fa
#   Step 3 break up the sequences so we can use more processors
#       fracfile.sh             breaks sequences.fa into -np parts for basting
#           fracsequence.pl     breaks fasta sequence into np parts for blasting
#   Step 4 Make fasta database
#       createdb.sh             makes fasta database out of sequences.fa
#           formatdb            blast program to format sequences.fa into database
#   Step 5 Blast
#       blastqsub.sh           job array of np elements that blasts each fraction of sequences.fa against database of sequences.fa
#           blastall            blast program that does the compares
#   Step 6 Combine blasts back together
#       catjob.sh               concationates blast output files together into blastfinal.tab
#           cat                 linux program to read a file out
#   Step 7 Remove extra edge information
#       blastreduce.sh          removes like and reverse matches of blastfinal.tab and saves as 1.out
#           sort                sort blast results so that the best blast results (via bitscore) are first
#           blastreduce.pl      actually does the heavy lifting
#           rm                  removes blastfinal.tab
#   Step 8 Add back in edges removed by step 2
#       demux.sh                adds blast results back in for sequences that were removed in multiplex step
#           mv                  moves current 1.out to mux.out
#           demux.pl            reads in mux.out and sequences.fa.clustr and generates new 1.out
#   Step 9 Make graphs 
#       graphs.sh               creates percent identity and alignment length quartiles as well as sequence length and edge value bar graphs
#           mkdir               makes directory for R quartile information (rdata)
#           Rgraphs.pl          reads through 1.out and saves tab delimited files for use in bar graphs (length.tab edge.tab)
#           Rgraphs.pl          saves quartile data into rdata
#           paste               makes tab delimited files like R needs from rdata/align* and rdata/perid* and makes align.tab and perid.tab
#           quart-align.r       Makes alignment length quartile graph (r_quartile_align.png) from tab file
#           quart-perid.r       Makes percent identity quartile graph (r_quartile_perid.png) from tab file
#           hist-length.r       Makes sequence length bar graph (r_hist_length.png) from tab file
#           hist-edges.r        Makes edges bar graph (r_hist_edges.png) from tab file
#

use strict;
use warnings;

use FindBin;
use Cwd qw(abs_path);
use File::Basename;
use Getopt::Long qw(:config pass_through);
use POSIX qw(ceil);
use EFI::SchedulerApi;
use EFI::Util qw(usesSlurm getLmod);
use EFI::Config qw(cluster_configure);

use lib "$FindBin::Bin/lib";
use Constants;


my ($np, $queue, $resultsDirName, $evalue, $incfrac, $ipro, $pfam, $accessionId, $accessionFile, $taxid);
my ($gene3d, $ssf, $blasthits, $searchSens, $searchHits, $memqueue, $maxsequence, $maxFullFam, $fastaFile, $useFastaHeaders);
my ($seqCountFile, $lengthdif, $noMatchFile, $sim, $multiplexing, $domain, $fraction);
my ($searchProgram, $jobId, $unirefVersion, $noDemuxArg, $cdHitOnly);
my ($scheduler, $dryrun, $LegacyGraphs, $configFile, $removeTempFiles);
my ($minSeqLen, $maxSeqLen, $forceDomain, $domainFamily, $clusterNode, $domainRegion, $excludeFragments, $taxSearch, $taxSearchOnly, $sourceTax, $familyFilter, $extraRam);
my ($runSerial, $useNoModules, $jobDir, $debug, $envScripts, $zipTransfer);
my $result = GetOptions(
    "np=i"              => \$np,
    "queue=s"           => \$queue,
    "results-dir-name=s"=> \$resultsDirName,
    "job-dir=s"         => \$jobDir,
    "evalue=s"          => \$evalue,
    "incfrac=f"         => \$incfrac,
    "ipro=s"            => \$ipro,
    "pfam=s"            => \$pfam,
    "accession-id=s"    => \$accessionId,
    "useraccession=s"   => \$accessionFile,
    "taxid=s"           => \$taxid,
    "gene3d=s"          => \$gene3d,
    "ssf=s"             => \$ssf,
    "blasthits=i"       => \$blasthits,
    "memqueue|mem-queue=s"  => \$memqueue,
    "maxsequence=s"     => \$maxsequence,
    "max-full-family=i" => \$maxFullFam,
    "userfasta=s"       => \$fastaFile,
    "use-fasta-headers" => \$useFastaHeaders,
    "seq-count-file=s"  => \$seqCountFile,
    "lengthdif=s"       => \$lengthdif,
    "no-match-file=s"   => \$noMatchFile,
    "sim=s"             => \$sim,
    "multiplex=s"       => \$multiplexing,
    "domain:s"          => \$domain,
    "domain-family=s"   => \$domainFamily,
    "domain-region=s"   => \$domainRegion,
    "force-domain=i"    => \$forceDomain,
    "fraction=i"        => \$fraction,
    "search-program=s"  => \$searchProgram,
    "search-sens=f"     => \$searchSens,
    "search-hits=i"     => \$searchHits,
    "job-id=i"          => \$jobId,
    "no-demux"          => \$noDemuxArg,
    "min-seq-len=i"     => \$minSeqLen,
    "max-seq-len=i"     => \$maxSeqLen,
    "cd-hit=s"          => \$cdHitOnly,     # specify this flag in order to run cd-hit only after getsequence-domain.pl then exit.
    "uniref-version=s"  => \$unirefVersion,
    "scheduler=s"       => \$scheduler,     # to set the scheduler to slurm 
    "dryrun"            => \$dryrun,        # to print all job scripts to STDOUT and not execute the job
    "cluster-node=s"    => \$clusterNode,
    "oldgraphs"         => \$LegacyGraphs,  # use the old graphing code
    "remove-temp"       => \$removeTempFiles, # add this flag to remove temp files
    "config=s"          => \$configFile,    # new-style config file
    "exclude-fragments" => \$excludeFragments,
    "serial-script=s"   => \$runSerial,     # run in serial mode
    "tax-search=s"      => \$taxSearch,
    "tax-search-only"   => \$taxSearchOnly,
    "source-tax=s"      => \$sourceTax,
    "family-filter=s"   => \$familyFilter,
    "extra-ram:i"       => \$extraRam,
    "no-modules"        => \$useNoModules,
    "env-scripts=s"     => \$envScripts,
    "debug"             => \$debug,
    "zip-transfer"      => \$zipTransfer,   # If this is true, exchange data with the special compressed file data_transfer.zip rather than using individual files.
);

die "Environment variables not set properly: missing EFIDB variable" if not exists $ENV{EFIDB};

my $efiEstTools = $ENV{EFIEST};
my $efiEstMod = $ENV{EFIESTMOD};
my $efiDbMod = $ENV{EFIDBMOD};
my $sortdir = '/scratch';

#defaults and error checking for choosing of blast program
$searchProgram = lc($searchProgram // "");
if ($searchProgram and $searchProgram ne "blast" and $searchProgram ne "blast+" and $searchProgram ne "blast+simple" and $searchProgram ne "diamond" and $searchProgram ne "diamondsensitive" and $searchProgram ne "mmseqs2") {
    die "blast program value of $searchProgram is not valid, must be blast, blast+, diamondsensitive, diamond, or mmseqs2\n";
} elsif (not $searchProgram) {
    $searchProgram = "blast";
}

# Defaults and error checking for splitting sequences into domains
if (defined $domain and $domain ne "off") {
    $domain = "on";
} elsif (not defined $domain) {
    $domain = "off";
    $domainFamily = "";
}

# Defaults for fraction of sequences to fetch
if (defined $fraction and $fraction !~ /^\d+$/ and $fraction <= 0) {
    die "if fraction is defined, it must be greater than zero\n";
} elsif (not defined $fraction) {
    $fraction=1;
}

if (not defined $cdHitOnly or not $lengthdif or not $sim) {
    # Defaults and error checking for multiplexing
    if (not $multiplexing) {
        $multiplexing = "on";
        if (defined $lengthdif and $lengthdif !~ /\d(\.\d+)?/) {
            die "lengthdif must be in a format like 0.9 |$lengthdif|\n";
        } elsif (not defined $lengthdif) {
            $lengthdif=1;
        }
        if (defined $sim and $sim !~ /\d(\.\d+)?/) {
            die "sim must be in a format like 0.9\n";
        } elsif (not defined $sim) {
            $sim=1;
        }
    } elsif ($multiplexing eq "on") {
        if (defined $lengthdif and $lengthdif !~ /\d(\.\d+)?/) {
            die "lengthdif must be in a format like 0.9 |$lengthdif|\n";
        } elsif (not defined $lengthdif) {
            $lengthdif=1;
        }
        if (defined $sim and $sim !~ /\d(\.\d+)?/) {
            die "sim must be in a format like 0.9\n";
        } elsif (not defined $sim) {
            $sim=1;
        }
    } elsif ($multiplexing eq "off") {
        if (defined $lengthdif and $lengthdif !~ /\d(\.\d+)?/) {
            die "lengthdif must be in a format like 0.9 |$lengthdif|\n";
        } elsif (not defined $lengthdif) {
            $lengthdif=1;
        }
        if (defined $sim and $sim !~ /\d(\.\d+)?/) {
            die "sim must be in a format like 0.9\n";
        } elsif (not defined $sim) {
            $sim=1;
        } 
    } else {
        die "valid variables for multiplexing are either on or off\n";
    }
}


# At least one of tehse inputs are required to get sequences for the program
if (not (defined $fastaFile or defined $ipro or defined $pfam or defined $taxid or defined $ssf or defined $gene3d or
        defined $accessionId or defined $accessionFile)) {
    die "You must spedify the -fasta, -ipro, -taxid, -pfam, -accession-id, or -useraccession arguments\n";
}

# You also have to specify the number of processors for blast
if (not defined $np) {
    if (exists $ENV{EFI_NP}) {
        $np = $ENV{EFI_NP};
    } else {
        die "You must spedify the -np variable\n";
    }
}

# Default queues
if (not defined $queue) {
    if (exists $ENV{EFI_QUEUE}) {
        $queue = $ENV{EFI_QUEUE};
    } else {
        die "-queue not specified\n";
    }
}
if (not defined $memqueue) {
    if (exists $ENV{EFI_MEMQUEUE}) {
        $memqueue = $ENV{EFI_MEMQUEUE};
    } else {
        die "-memqueue not specifiied\n";
    }
}

# Default e value must also be set for blast, default set if not specified
if (not defined $evalue) {
    print "-evalue not specified, using default of 5\n";
    $evalue = "1e-5";
} else {
    if ( $evalue =~ /^\d+$/ ) { 
        $evalue = "1e-$evalue";
    }
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

if (exists $ENV{EFI_LEGACY_GRAPHS}) {
    $LegacyGraphs = 1;
}

my $manualCdHit = 0;
$manualCdHit = 1 if (not defined $cdHitOnly and ($lengthdif < 1 or $sim < 1) and defined $noDemuxArg);

$seqCountFile = ""  if not defined $seqCountFile;
$cdHitOnly = ""     if not defined $cdHitOnly;

$np = ceil($np / 24) if ($searchProgram=~/diamond/);

# Max number of hits for an individual sequence, normally set ot max value
$blasthits = 1000000 if not (defined $blasthits);
$blasthits = $searchHits ? $searchHits : $blasthits;

# Wet input families to zero if they are not specified
$pfam = 0           if not defined $pfam;
$ipro = 0           if not defined $ipro;
$taxid = 0          if not defined $taxid;
$gene3d = 0         if not defined $gene3d;
$ssf = 0            if not defined $ssf;
$accessionId = 0    if not defined $accessionId;

$unirefVersion = "" if not defined $unirefVersion;
$maxFullFam = 0     if not defined $maxFullFam;
$fastaFile = ""     if not defined $fastaFile;
$accessionFile = "" if not defined $accessionFile;
$minSeqLen = 0      if not defined $minSeqLen;
$maxSeqLen = 0      if not defined $maxSeqLen;
$forceDomain = 0    if not defined $forceDomain;
$domainFamily = ""  if not defined $domainFamily;
$domainRegion = "domain" if not defined $domainRegion;

# Maximum number of sequences to process, 0 disables it
$maxsequence = 0    if not defined $maxsequence;

# Fraction of sequences to include in graphs, reduces effects of outliers
if (not defined $incfrac) {
    print "-incfrac not specified, using default of 1\n";
    $incfrac = 1; # was 0.99
}

$excludeFragments = defined($excludeFragments);
$runSerial = defined($runSerial) ? $runSerial : "";
$useFastaHeaders = ($taxSearchOnly or $useFastaHeaders);
$debug = 0 if not defined $debug;
my $useModuleSystem = not $useNoModules;

# We will keep the domain option on
#$domain = "off"     if $unirefVersion and not $forceDomain;

($jobId = $ENV{PWD}) =~ s%^.*/(\d+)/*$%$1% if not $jobId;
$jobId = "" if $jobId =~ /\D/;

$noMatchFile = ""   if not defined $noMatchFile;

if ($runSerial) {
    use EFI::Util::System;
    my $specs = getSystemSpec();
    $np = $specs->{num_cpu} / 2;
}



$jobDir = $ENV{PWD} if not $jobDir;
$resultsDirName = "output" if not $resultsDirName;
my $outputDir = "$jobDir/$resultsDirName";

my $pythonMod = "Python"; #getLmod("Python/2", "Python");
my $gdMod = "GD/2.73-IGB-gcc-8.2.0-Perl-5.28.1"; #getLmod("GD.*Perl", "GD");
#my $perlMod = "Perl";
#my $rMod = "R";

print "Blast is $searchProgram\n";
print "domain is $domain\n";
print "domain-family is $domainFamily\n";
print "fraction is $fraction\n";
print "multiplexing is $multiplexing\n";
print "lengthdif is $lengthdif\n";
print "sim is $sim\n";
print "fasta is $fastaFile\n";
print "ipro is $ipro\n";
print "pfam is $pfam\n";
print "taxid is $taxid\n";
print "ssf is $ssf\n";
print "gene3d is $gene3d\n";
print "accession-id is $accessionId\n";
print "useraccession is $accessionFile\n";
print "no-match-file is $noMatchFile\n";
print "np is $np\n";
print "queue is $queue\n";
print "memqueue is $memqueue\n";
print "evalue is $evalue\n";
print "config is $configFile\n";
print "maxsequence is $maxsequence\n";
print "incfrac is $incfrac\n";
print "seq-count-file is $seqCountFile\n";
print "base output directory is $jobDir\n";
print "results directory name is $resultsDirName\n";
print "uniref-version is $unirefVersion\n";
print "manualcdhit is $manualCdHit\n";
print "Python module is $pythonMod\n";
print "max-full-family is $maxFullFam\n";
print "cd-hit is $cdHitOnly\n";
print "force-domain is $forceDomain\n";
print "exclude-fragments is $excludeFragments\n";
print "serial-script is $runSerial\n";
print "domain-region is $domainRegion\n";


my $accOutFile = "$outputDir/accession.txt";
my $errorFile = "$accOutFile.failed";

my $filtSeqFilename = "sequences.fa";

my $fracOutputDir = "$outputDir/fractions";
my $blastOutputDir = "$outputDir/blastout";
my $structFile = "$outputDir/struct.out";
my $allSeqFile = "$outputDir/allsequences.fa";
my $filtSeqFile = "$outputDir/$filtSeqFilename";

my $lenUniprotFile = "$outputDir/length_uniprot.tab"; # full lengths of all UniProt sequences (expanded from UniRef if necessary)
my $lenUniprotDomFile = "$outputDir/length_uniprot_domain.tab"; # domain lengths of all UniProt sequences (expanded from UniRef if necessary)
my $lenUniref90File = "$outputDir/length_uniref90.tab"; # full lengths of UR cluster ID sequences
my $lenUniref90DomFile = "$outputDir/length_uniref90_domain.tab"; # domain lengths of UR cluster ID sequences
my $lenUniref50File = "$outputDir/length_uniref50.tab"; # full lengths of UR cluster ID sequences
my $lenUniref50DomFile = "$outputDir/length_uniref50_domain.tab"; # domain lengths of UR cluster ID sequences
my $lenUnirefFile = "$outputDir/length_uniref.tab"; # full lengths of UR cluster ID sequences
my $lenUnirefDomFile = "$outputDir/length_uniref_domain.tab"; # domain lengths of UR cluster ID sequences
#my $uniprotSeqLenFile = "$outputDir/uniprot_length.tab"; # For UniRef option, this is the lengths of all the sequences in the family not just the seed sequences
#my $unirefClusterSeqLenFile = "$outputDir/uniref_cluster_length.tab"; # For UniRef + Domain option, this is the full lengths of the cluster ID sequences, not accounting for domain.

my $metadataFile = "$outputDir/" . EFI::Config::FASTA_META_FILENAME;

$seqCountFile = "$outputDir/acc_counts" if not $seqCountFile;
$seqCountFile = "$outputDir/$seqCountFile" if $seqCountFile !~ m%^/%;

my $taxOutputFile = "$outputDir/tax.json";
my $sunburstTaxOutput = "$outputDir/sunburst.raw";



my $accessionFileZip = $accessionFile;
my ($afn, $afp, $afx) = fileparse($accessionFile);
my $afname = "$afn.txt";
my $targetAccessionFile = "$jobDir/$afname";
if ($accessionFileZip =~ /\.zip$/i) {
    $accessionFile = $targetAccessionFile;
}
# Error checking for user supplied dat and fa files
my $accessionFileOption = "";
my $noMatchFileOption = "";
my $taxSourceAccessionFile = "";
if (defined $accessionFile and -e $accessionFile) {
    # If there a source tax option, we set the original file to be the json from the tax job.
    # Then the accessionFile becomes the output file from the get_tax_tree.pl script below,
    # before the tool chain starts.
    if ($sourceTax) {
        $taxSourceAccessionFile = $accessionFile;
        my ($taxJobId, $taxTreeId, $taxIdType) = split(m/,/, $sourceTax);
        $accessionFile = $jobDir . "/$taxJobId.txt";
        $accessionFileOption = "-accession-file $accessionFile";
    } elsif (not ($accessionFile =~ /^\//i or $accessionFile =~ /^~/)) {
        $accessionFile = $jobDir . "/$accessionFile";
        $accessionFileOption = "-accession-file $accessionFile";
    } else {
        $accessionFileOption = "-accession-file $targetAccessionFile";
    }

    $noMatchFile = "$outputDir/" . EFI::Config::NO_ACCESSION_MATCHES_FILENAME if !$noMatchFile;
    $noMatchFile = $outputDir . "/$noMatchFile" if not ($noMatchFile =~ /^\// or $noMatchFile =~ /^~/);
    $noMatchFileOption = "-no-match-file $noMatchFile";
} else {
    $accessionFile = "";
}


#if (defined $fastaFile and -e $fastaFile) { # and -e $metadataFile) {
##} elsif (defined $metadataFile) {
#} else {
#    die "$metadataFile does not exist\n";
##} else {
##    print "this is userdat:$metadataFile:\n";
##    $metadataFile = "";
#}

my $fastaFileZip = $fastaFile;
my ($ffn, $ffp, $ffx) = fileparse($fastaFile);
my $fastaFname = "$ffn.fasta";
my $targetFastaFile = "$jobDir/$fastaFname";
if ($fastaFileZip =~ /\.zip$/i) {
    $fastaFile = $targetFastaFile;
}
my $fastaFileOption = "";
if (defined $fastaFile and -e $fastaFile) {
    $fastaFile = "$jobDir/$fastaFile" if not ($fastaFile=~/^\// or $fastaFile=~/^~/);
    $fastaFileOption = "-fasta-file $targetFastaFile";
    $fastaFileOption = "-use-fasta-headers " . $fastaFileOption if defined $useFastaHeaders;
} else {
    $fastaFile = "";
}



# Create tmp directories
mkdir $outputDir;

# Write out the database version to a file
$efiDbMod=~/(\d+)$/;
my $dbVer = $1 // "";
print "database version is $dbVer of $efiDbMod\n";
system("echo $dbVer >$outputDir/database_version");

# Set up the scheduler API so we can work with Torque or Slurm.
my $schedType = "torque";
$schedType = "slurm" if (defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm());
my $usesSlurm = $schedType eq "slurm";


my $logDir = "$jobDir/log";
mkdir $logDir;
$logDir = "" if not -d $logDir;
my %schedArgs = (type => $schedType, queue => $queue, resource => [1, 1, "35gb"], dryrun => $dryrun);
$schedArgs{output_base_dirpath} = $logDir if $logDir;
$schedArgs{node} = $clusterNode if $clusterNode;
$schedArgs{extra_path} = $config->{cluster}->{extra_path} if $config->{cluster}->{extra_path};
$schedArgs{run_serial} = $runSerial ? 1 : 0;
my $S = new EFI::SchedulerApi(%schedArgs);

my $B = $S->getBuilder();

my $jobNamePrefix = $jobId ? $jobId . "_" : "";
my $progressFile = "$outputDir/progress";
initSerialScript($B) if $runSerial;

my $scriptDir = "$jobDir/scripts";
mkdir $scriptDir;
$scriptDir = $outputDir if not -d $scriptDir;


my @allJobIds;
my $sortPrefix = "br-";
my @a = (('a'..'z'), 0..9);
$sortPrefix .= $a[rand(@a)] for 1..5;


########################################################################################################################
# Get sequences and annotations.  This creates fasta and struct.out files.
#
$B->resource(1, 1, "5gb");
$B->mailEnd() if $taxSearchOnly;
my $prevJobId;

if ($pfam or $ipro or $ssf or $gene3d or ($fastaFile=~/\w+/ and !$taxid) or $accessionId or $accessionFile) {

    my $maxFullFamOption = $maxFullFam ? "-max-full-fam-ur90 $maxFullFam" : "";

    addModule($B, "module load $efiDbMod");
    addModule($B, "module load $efiEstMod");
    addModule($B, "module unload MariaDB");
    addModule($B, "module load MariaDB/10.3.17-IGB-gcc-8.2.0");
    $B->addAction("cd $outputDir");
    $B->addAction("unzip -p $fastaFileZip > $fastaFile") if $fastaFileZip =~ /\.zip$/i;
    $B->addAction("unzip -p $accessionFileZip > $accessionFile") if $accessionFileZip =~ /\.zip$/i;
    if ($fastaFile and not $sourceTax) {
        if ($fastaFileZip !~ /\.zip$/i) {
            $B->addAction("sed 's/\\n\\r/\\n/g' $fastaFile | sed 's/\\r/\\n/g' > $targetFastaFile");
            $fastaFile = $targetFastaFile;
        } else {
            $B->addAction("sed -i 's/\\n\\r/\\n/' $fastaFile");
            $B->addAction("sed -i 's/\\r/\\n/' $fastaFile");
        }
        #$B->addAction("dos2unix -q $fastaFile");
        #$B->addAction("mac2unix -q $fastaFile");
    }
    if ($accessionFile and not $sourceTax) {
        if ($accessionFileZip !~ /\.zip$/i) {
            $B->addAction("sed 's/\\n\\r/\\n/' $accessionFile | sed 's/\\r/\\n/' > $targetAccessionFile");
            $accessionFile = $targetAccessionFile;
        } else {
            $B->addAction("sed -i 's/\\n\\r/\\n/' $accessionFile");
            $B->addAction("sed -i 's/\\r/\\n/' $accessionFile");
        }
        #$B->addAction("dos2unix -q $accessionFile");
        #$B->addAction("mac2unix -q $accessionFile");
    }
    # Don't enforce the limit here if we are using manual cd-hit parameters below (the limit
    # is checked below after cd-hit).
    my $maxSeqOpt = $manualCdHit ? "" : "-maxsequence $maxsequence";
    my $minSeqLenOpt = $minSeqLen ? "-min-seq-len $minSeqLen" : "";
    my $maxSeqLenOpt = $maxSeqLen ? "-max-seq-len $maxSeqLen" : "";

    my $domFamArg = $domainFamily ? "-domain-family $domainFamily" : "";
    my $domRegionArg = ($domainRegion eq "cterminal" or $domainRegion eq "nterminal") ? "-domain-region $domainRegion" : "";

    my @args = (
        "-config=$configFile", "-error-file $errorFile",
        "-seq-count-output $seqCountFile", "-sequence-output $allSeqFile", "-accession-output $accOutFile",
        "-meta-file $metadataFile", $minSeqLenOpt, $maxSeqLenOpt
    );
    push @args, "--sunburst-tax-output $sunburstTaxOutput";

    push @args, "-pfam $pfam" if $pfam;
    push @args, "-ipro $ipro" if $ipro;
    push @args, "-ssf $ssf" if $ssf;
    push @args, "-gene3d $gene3d" if $gene3d;
    if ($pfam or $ipro or $ssf or $gene3d) {
        push @args, "-uniref-version $unirefVersion" if $unirefVersion;
        push @args, "-max-full-fam-ur90 $maxFullFam" if $maxFullFam;
        push @args, "-fraction $fraction" if $fraction;
    }
    if ($domain eq "on") {
        push @args, "-domain $domain";
        push @args, "-uniprot-dom-len-output $lenUniprotDomFile";
        push @args, "-uniref-dom-len-output $lenUnirefDomFile" if $unirefVersion;
        push @args, $domFamArg if $domFamArg;
        push @args, $domRegionArg if $domainRegion;
    }

    push @args, "--debug-sql" if $debug;

    my $retrScript = "get_sequences_option_";
    if (not $fastaFile and not $accessionFile) {
        $retrScript .= "b.pl";
    } elsif ($fastaFile and $fastaFileOption) {
        $retrScript .= "c.pl";
        push @args, $fastaFileOption;
        push @args, "--uniref-version $unirefVersion" if $unirefVersion and not($pfam or $ipro or $ssf or $gene3d); # Don't add this arg if the family is included, because the arg is already included in the family section
        push @args, "--family-filter \"$familyFilter\"" if $familyFilter;
    } elsif ($accessionFile) {
        $retrScript .= "d.pl";
        push @args, "--uniref-version $unirefVersion" if $unirefVersion and not($pfam or $ipro or $ssf or $gene3d); # Don't add this arg if the family is included, because the arg is already included in the family section
        push @args, $accessionFileOption;
        push @args, $noMatchFileOption;
        push @args, "--family-filter \"$familyFilter\"" if $familyFilter;
    }

    push @args, "-exclude-fragments" if $excludeFragments;

    #push @args, "--tax-search \"$taxSearch\" --tax-output $taxOutputFile" if $taxSearch;
    my $taxOpt = $taxSearch ? "--tax-search \"$taxSearch\"" : "";
    push @args, $taxOpt if $taxOpt;

    if ($accessionFile and $sourceTax) {
        my ($taxJobId, $taxTreeId, $taxIdType) = split(m/,/, $sourceTax);
        my @srcArgs = ("--json-file", $taxSourceAccessionFile, "--tree-id", $taxTreeId, "--id-type", $taxIdType, "--output-file", $accessionFile);
        $B->addAction("$efiEstTools/extract_taxonomy_tree.pl " . join(" ", @srcArgs));
    }
    $B->addAction("$efiEstTools/$retrScript " . join(" ", @args));

    #if ($taxSearchOnly or not $fastaFile) {
    {
        #my $useUnirefArg = (not $fastaFile and not $accessionFile) ? "--use-uniref" : "";
        # If a uniref version is specified, assume that the input IDs are that version, expand them, and then get
        # the taxonomy for that and all uniref IDs.  If a uniref version is not specified, then get the taxonomy for that and all uniref IDs.
        #my $useUnirefArg = (not $fastaFile) ? ("--use-uniref" . ($unirefVersion ? " --uniref-version $unirefVersion" : "")) : "";
        #$B->addAction("$efiEstTools/get_taxonomy.pl --output-file $taxOutputFile --metadata-file $metadataFile --config $configFile $useUnirefArg");
        #my $sourceFileArg = $accessionFile ? "--metadata-file $metadataFile" : "--accession-file $accOutFile";
        #my $sourceFileArg = "--accession-file $accOutFile";
        my $sourceFileArg = "--sunburst-id-file $sunburstTaxOutput";
        $B->addAction("$efiEstTools/get_taxonomy.pl --output-file $taxOutputFile $sourceFileArg --config $configFile"); # Remove the legacy after summer 2022
    }

    my @lenUniprotArgs = ("--metadata-file $metadataFile", "--config $configFile");
    push @lenUniprotArgs, "--output $lenUniprotFile";
    push @lenUniprotArgs, "--expand-uniref" if $unirefVersion;
    push @lenUniprotArgs, "--output-uniref50-len $lenUniref50File --output-uniref90-len $lenUniref90File" if $taxSearchOnly;
    push @lenUniprotArgs, "--use-metadata-file-seq-len" if $fastaFile and $fastaFileOption;
    $B->addAction("$efiEstTools/get_lengths_from_anno.pl " . join(" ", @lenUniprotArgs));

    if ($unirefVersion and not $taxSearchOnly) {
        my @lenUnirefArgs = ("-struct $metadataFile", "-config $configFile");
        push @lenUnirefArgs, "-output $lenUnirefFile";
        $B->addAction("$efiEstTools/get_lengths_from_anno.pl " . join(" ", @lenUnirefArgs));
    }

    # Annotation retrieval (getannotations.pl) now happens in the SNN/analysis step.

    if ($taxSearchOnly) {
        createGraphJob($B, undef, "50+90", 0, 1);
        $B->addAction("formatdb -i $allSeqFile -n database -p T -o T ");
        $B->addAction("touch $outputDir/1.out.completed");
    }

    $B->addAction("echo 33 > $progressFile");
    $B->jobName("${jobNamePrefix}initial_import");
    $B->renderToFile(getRenderFilePath("$scriptDir/initial_import.sh"));

    # Submit and keep the job id for next dependancy
    my $importjob = $S->submit("$scriptDir/initial_import.sh");
    chomp $importjob;

    print "import job is:\n $importjob\n" if not $runSerial;
    ($prevJobId) = split(/\./, $importjob);

    if ($taxSearchOnly) {
        exit;
    }

# Tax id code is different, so it is exclusive
} elsif ($taxid) {

    addModule($B, "module load $efiDbMod");
    addModule($B, "module load $efiEstMod");
    $B->addAction("cd $outputDir");
    $B->addAction("$efiEstTools/get_sequences_by_tax_id.pl -fasta allsequences.fa -struct $structFile -taxid $taxid -config=$configFile");
    if ($fastaFile=~/\w+/) {
        $fastaFile=~s/^-userfasta //;
        $B->addAction("cat $fastaFile >> allsequences.fa");
    }
    #TODO: handle the header file for this case....
    if ($metadataFile=~/\w+/) {
        $metadataFile=~s/^-userdat //;
        $B->addAction("cat $metadataFile >> $structFile");
    }
    $B->jobName("${jobNamePrefix}initial_import");
    $B->renderToFile(getRenderFilePath("$scriptDir/initial_import.sh"));

    my $importjob = $S->submit("$scriptDir/initial_import.sh");
    chomp $importjob;

    print "import job is:\n $importjob\n" if not $runSerial;
    ($prevJobId) = split /\./, $importjob;
} else {
    # die "Error Submitting Import Job\nYou cannot mix ipro, pfam, ssf, and gene3d databases with taxid\n";
}

push @allJobIds, $prevJobId;



#######################################################################################################################
# Try to reduce the number of sequences to speed up computation.
# If multiplexing is on, run an initial cdhit to get a reduced set of "more" unique sequences.
# If not, just copy allsequences.fa to sequences.fa so next part of program is set up right.
#
$B = $S->getBuilder();
$B->dependency(0, $prevJobId);
$B->mailEnd() if defined $cdHitOnly;

# If we only want to do CD-HIT jobs then do that here.
if ($cdHitOnly) {
    $B->resource(1, 24, "10GB");
    addModule($B, "module load $efiDbMod");
    addModule($B, "module load $efiEstMod");
    #addModule($B, "module load blast");
    $B->addAction("cd $outputDir");

    my @seqId = split /,/, $sim;
    my @seqLength = split /,/, $lengthdif;

    for (my $i = 0; $i <= $#seqId; $i++) {
        my $sLen = $#seqId == $#seqLength ? $seqLength[$i] : $seqLength[0];
        my $sId = $seqId[$i];
        my $nParm = ($sId < 1 and $sLen < 1) ? "-n 2" : "";
        $B->addAction("cd-hit -d 0 $nParm -c $sId -s $sLen -i $allSeqFile -o $outputDir/sequences-$sId-$sLen.fa -M 20000 -n 2");
        $B->addAction("$efiEstTools/get_cluster_count.pl -id $sId -len $sLen -cluster $outputDir/sequences-$sId-$sLen.fa.clstr >> $cdHitOnly");
    }
    $B->addAction("touch  $outputDir/1.out.completed");

    $B->jobName("${jobNamePrefix}cdhit");
    $B->renderToFile(getRenderFilePath("$scriptDir/cdhit.sh"));
    my $cdhitjob = $S->submit("$scriptDir/cdhit.sh");
    chomp $cdhitjob;
    print "CD-HIT job is:\n $cdhitjob\n" if not $runSerial;
    exit;
}

$B->resource(1, 1, "10gb");

addModule($B, "module load $efiDbMod");
addModule($B, "module load $efiEstMod");
#addModule($B, "module load blast");
$B->addAction("cd $outputDir");

if ($multiplexing eq "on") {
    my $nParm = ($sim < 1 and $lengthdif < 1) ? "-n 2" : "";
    $B->addAction("cd-hit -d 0 $nParm -c $sim -s $lengthdif -i $allSeqFile -o $filtSeqFile -M 10000");

    if ($manualCdHit) {
        $B->addAction(<<CMDS
if $efiEstTools/check_seq_count.pl -max-seq $maxsequence -error-file $errorFile -cluster $filtSeqFile.clstr
then
    echo "Sequence count OK"
else
    echo "Sequence count not OK"
    exit 1
fi
CMDS
            );
        $B->addAction("mv $allSeqFile $allSeqFile.before_demux");
        $B->addAction("cp $filtSeqFile $allSeqFile");
    }
    # Add in CD-HIT attributes to SSN
    if ($noDemuxArg) {
        $B->addAction("$efiEstTools/get_demux_ids.pl -struct $structFile -cluster $filtSeqFile.clstr -domain $domain");
    }
} else {
    $B->addAction("cp $allSeqFile $filtSeqFile");
}
$B->jobName("${jobNamePrefix}multiplex");
$B->renderToFile(getRenderFilePath("$scriptDir/multiplex.sh"));

my $muxjob = $S->submit("$scriptDir/multiplex.sh");
chomp $muxjob;
print "mux job is:\n $muxjob\n" if not $runSerial;
($prevJobId) = split /\./, $muxjob;

push @allJobIds, $prevJobId;


my $blastDb = "$outputDir/database";
if ($searchProgram eq "mmseqs2") {

    $B = $S->getBuilder();
    $B->resource(1, 1, "50gb");

    my $dbOutDir = "$outputDir/mmseqs2_tmp";
    $blastDb = "$dbOutDir/database";
    $B->dependency(0, $prevJobId);
    addModule($B, "module load MMseqs2");
    $B->addAction("mkdir $dbOutDir");
    $B->addAction("mmseqs createdb $filtSeqFile $blastDb");
    $B->addAction("mmseqs createindex $blastDb idx");
    $B->jobName("${jobNamePrefix}createdb");
    $B->renderToFile(getRenderFilePath("$scriptDir/createdb.sh"));

    my $createdbjob = $S->submit("$scriptDir/createdb.sh");
    chomp $createdbjob;
    print "createdb job is:\n $createdbjob\n" if not $runSerial;
    ($prevJobId) = split /\./, $createdbjob;

    push @allJobIds, $prevJobId;

} else {

    ########################################################################################################################
    # Break sequenes.fa into parts so we can run blast in parallel.
    #
    $B = $S->getBuilder();
    $B->resource(1, 1, "5gb");

    $B->dependency(0, $prevJobId);
    $B->addAction("mkdir -p $fracOutputDir");
    $B->addAction("$efiEstTools/split_fasta.pl -parts $np -tmp $fracOutputDir -source $filtSeqFile");
    $B->jobName("${jobNamePrefix}fracfile");
    $B->renderToFile(getRenderFilePath("$scriptDir/fracfile.sh"));

    my $fracfilejob = $S->submit("$scriptDir/fracfile.sh");
    chomp $fracfilejob;
    print "fracfile job is:\n $fracfilejob\n" if not $runSerial;
    ($prevJobId) = split /\./, $fracfilejob;

    push @allJobIds, $prevJobId;


    ########################################################################################################################
    # Make the blast database and put it into the temp directory
    #
    $B = $S->getBuilder();

    $B->dependency(0, $prevJobId);
    $B->resource(1, 1, "5gb");
    addModule($B, "module load $efiDbMod");
    addModule($B, "module load $efiEstMod");
    $B->addAction("cd $outputDir");
    if ($searchProgram eq 'diamond' or $searchProgram eq 'diamondsensitive') {
        addModule($B, "module load diamond");
        $B->addAction("diamond makedb --in $filtSeqFilename -d database");
    } else {
        $B->addAction("formatdb -i $filtSeqFilename -n database -p T -o T ");
    }
    $B->jobName("${jobNamePrefix}createdb");
    $B->renderToFile(getRenderFilePath("$scriptDir/createdb.sh"));

    my $createdbjob = $S->submit("$scriptDir/createdb.sh");
    chomp $createdbjob;
    print "createdb job is:\n $createdbjob\n" if not $runSerial;
    ($prevJobId) = split /\./, $createdbjob;

    push @allJobIds, $prevJobId;
}



########################################################################################################################
# Generate job array to blast files from fracfile step
#
my $blastFinalFile = "$outputDir/blastfinal.tab";

$B = $S->getBuilder();
mkdir $blastOutputDir;

$B->setScriptAbortOnError(0); # Disable SLURM aborting on errors, since we want to catch the BLAST error and report it to the user nicely
$B->jobArray("1-$np") if $searchProgram eq "blast";
$B->dependency(0, $prevJobId);
$B->resource(1, 1, "5gb") if $searchProgram eq "blast";
$B->resource(1, $np, "50G") if $searchProgram eq "mmseqs2";
$B->resource(1, $np, "14G") if $searchProgram =~ /diamond/i;
$B->resource(1, $np, "14G") if $searchProgram =~ /blast\+/i;

$B->addAction("export BLASTDB=$outputDir");
#addModule($B, "module load blast+");
#$B->addAction("blastp -query  $fracOutputDir/fracfile-{JOB_ARRAYID}.fa  -num_threads 2 -db database -gapopen 11 -gapextend 1 -comp_based_stats 2 -use_sw_tback -outfmt \"6 qseqid sseqid bitscore evalue qlen slen length qstart qend sstart send pident nident\" -num_descriptions 5000 -num_alignments 5000 -out $blastOutputDir/blastout-{JOB_ARRAYID}.fa.tab -evalue $evalue");
addModule($B, "module load $efiDbMod");
addModule($B, "module load $efiEstMod");
my $outputFiles = "";
if ($searchProgram eq "blast") {
    #addModule($B, "module load blast");
    if ($runSerial) {
        open my $fh, ">", "$scriptDir/blast.sh";
        print $fh "#!/bin/bash\n";
        print $fh getModuleEntry("module load $efiEstMod\n");
        print $fh "blastall -p blastp -d $blastDb -m 8 -e $evalue -b $blasthits -o $blastOutputDir/blastout-\$1.fa.tab -i $fracOutputDir/fracfile-\$1.fa\n";
        close $fh;
        chmod 0755, "$scriptDir/blast.sh";
        $B->addAction("echo {1..$np} | xargs -n 1 -P $np $scriptDir/blast.sh");
    } else {
        $B->addAction("blastall -p blastp -i $fracOutputDir/fracfile-{JOB_ARRAYID}.fa -d $blastDb -m 8 -e $evalue -b $blasthits -o $blastOutputDir/blastout-{JOB_ARRAYID}.fa.tab");
    }
    $outputFiles = "$blastOutputDir/blastout-*.tab";
} elsif ($searchProgram eq "blast+") {
    addModule($B, "module load BLAST+");
    $B->addAction("blastp -query $filtSeqFile -num_threads $np -db $blastDb -gapopen 11 -gapextend 1 -comp_based_stats 2 -use_sw_tback -outfmt \"6\" -max_hsps 1 -num_descriptions $blasthits -num_alignments $blasthits -out $blastFinalFile -evalue $evalue");
} elsif ($searchProgram eq "blast+simple") {
    addModule($B, "module load BLAST+");
    $B->addAction("blastp -query $filtSeqFile -num_threads $np -db $blastDb -outfmt \"6\" -num_descriptions $blasthits -num_alignments $blasthits -out $blastFinalFile -evalue $evalue");
} elsif ($searchProgram eq "diamond") {
    addModule($B, "module load DIAMOND");
    $B->addAction("diamond blastp -p $np -e $evalue -k $blasthits -C $blasthits -q $filtSeqFile -d $blastDb -a $blastOutputDir/blastout.daa");
    $B->addAction("diamond view -o $blastFinalFile -f tab -a $blastOutputDir/blastout.daa");
} elsif ($searchProgram eq "diamondsensitive") {
    addModule($B, "module load DIAMOND");
    $B->addAction("diamond blastp --sensitive -p $np -e $evalue -k $blasthits -C $blasthits -q $fracOutputDir/fracfile-{JOB_ARRAYID}.fa -d $blastDb -a $blastOutputDir/blastout.daa");
    $B->addAction("diamond view -o $blastFinalFile -f tab -a $blastOutputDir/blastout.daa");
} elsif ($searchProgram eq "mmseqs2") {
    addModule($B, "module load MMseqs2");
    my $mmOutFile = "$outputDir/search_res";
    $searchSens = "7" if not $searchSens;
    my $maxSeqs = $searchHits ? "--max-seqs $searchHits" : "";
    $B->addAction("mmseqs search --threads $np -s $searchSens $maxSeqs $blastDb $blastDb $mmOutFile.out idx");
    #$B->addAction("mmseqs search --threads $np -s $searchSens $maxSeqs $filtSeqFile $blastDb $mmOutFile.out idx");
    $B->addAction("mmseqs convertalis $blastDb $blastDb $mmOutFile.out $mmOutFile.m8");
    $outputFiles = "$mmOutFile.m8";
} else {
    die "Blast control not set properly.  Can only be blast, blast+, or diamond.\n";
}
$B->addAction("OUT=\$?");
$B->addAction("if [ \$OUT -ne 0 ]; then");
$B->addAction("    echo \"BLAST failed; likely due to file format.\"");
$B->addAction("    echo \$OUT > $outputDir/blast.failed");
$B->addAction("    exit 1");
$B->addAction("fi");
$B->addAction("echo 50 > $progressFile");
$B->jobName("${jobNamePrefix}blastqsub");
$B->renderToFile(getRenderFilePath("$scriptDir/blastqsub.sh"));

$B->jobArray("");
my $blastjob = $S->submit("$scriptDir/blastqsub.sh");
chomp $blastjob;
print "blast job is:\n $blastjob\n" if not $runSerial;
($prevJobId) = split /\./, $blastjob;

push @allJobIds, $prevJobId;


########################################################################################################################
# Join all the blast outputs back together
#
$B = $S->getBuilder();

$B->resource(1, 1, "16gb");
$B->dependency(1, $prevJobId);
# $B->addAction("cat $outputFiles |grep -v '#'|cut -f 1,2,3,4,12 >$blastFinalFile") if $outputFiles;
# $B->addAction("SZ=`stat -c%s $blastFinalFile`");
# $B->addAction("if [[ \$SZ == 0 ]]; then");
# $B->addAction("    echo \"BLAST Failed. Check input file.\"");
# $B->addAction("    touch $outputDir/blast.failed");
# $B->addAction("    exit 1");
# $B->addAction("fi");
addModule($B, "module load Python/3.10.1-IGB-gcc-8.2.0");
addModule($B, "module load efiest/python_est_1.0");
$B->addAction("~/EST/efi-env/bin/python ~/EST/blastreduce/transcode.py --blast-output $outputDir/blastout --fasta $filtSeqFile --output-file $outputDir/1.out.parquet --sql-template ~/EST/blastreduce/reduce-template.sql --sql-output-file $outputDir/reduce.sql --duckdb-temp-dir $outputDir/duckdb --duckdb-memory-limit 8GB");
$B->addAction("/home/groups/efi/apps/bin/duckdb < $outputDir/reduce.sql");
$B->jobName("${jobNamePrefix}catjob");
$B->renderToFile(getRenderFilePath("$scriptDir/blastreduce.sh"));
my $catjob = $S->submit("$scriptDir/blastreduce.sh");
chomp $catjob;
print "Cat job is:\n $catjob\n" if not $runSerial;
($prevJobId) = split /\./, $catjob;

push @allJobIds, $prevJobId;


########################################################################################################################
# If multiplexing is on, demultiplex sequences back so all are present
#
$B = $S->getBuilder();

$B->dependency(0, $prevJobId);
$B->resource(1, 1, "5gb");
addModule($B, "module load $efiDbMod");
addModule($B, "module load $efiEstMod");
if ($multiplexing eq "on" and not $manualCdHit and not $noDemuxArg) {
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

my $demuxjob = $S->submit("$scriptDir/demux.sh");
chomp $demuxjob;
print "Demux job is:\n $demuxjob\n" if not $runSerial;
($prevJobId) = split /\./, $demuxjob;

push @allJobIds, $prevJobId;


########################################################################################################################
# Compute convergence ratio
#
$B = $S->getBuilder();
$B->dependency(0, $prevJobId);
$B->resource(1, 1, "5gb");

$B->addAction("$efiEstTools/calc_blast_stats.pl -edge-file $outputDir/1.out -seq-file $allSeqFile -unique-seq-file $filtSeqFile -seq-count-output $seqCountFile");
$B->jobName("${jobNamePrefix}conv_ratio");
$B->renderToFile(getRenderFilePath("$scriptDir/conv_ratio.sh"));
my $convRatioJob = $S->submit("$scriptDir/conv_ratio.sh");
chomp $convRatioJob;
print "Convergence ratio job is:\n $convRatioJob\n" if not $runSerial;
my @convRatioJobLine=split /\./, $convRatioJob;

push @allJobIds, $convRatioJobLine[0];

########################################################################################################################
# Create information for R to make graphs and then have R make them
#
$B = $S->getBuilder();

my $separateJob = 1;
my $lengthHistoOnly = 0;
$prevJobId = createGraphJob($B, $prevJobId, $unirefVersion, $separateJob, $lengthHistoOnly);
push @allJobIds, $prevJobId;


$B = $S->getBuilder();

my @transferFiles = ("$outputDir/1.out", "$outputDir/allsequences.fa", "$outputDir/". EFI::Config::FASTA_META_FILENAME);

$B->resource(1, 1, "1gb");
$B->dependency(1, \@allJobIds);
#$B->addAction("rm -f $sortdir/*");
$B->addAction("zip -j $outputDir/data_transfer.zip " . join(" ", @transferFiles)) if $zipTransfer;
$B->jobName("${jobNamePrefix}cleanuperr");
$B->renderToFile(getRenderFilePath("$scriptDir/cleanuperr.sh"));
my $cleanupErrJob = $S->submit("$scriptDir/cleanuperr.sh");
$prevJobId = getJobId($cleanupErrJob);

push @allJobIds, $prevJobId;

print "All Job IDs:\n" . join(",", @allJobIds) . "\n";





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


sub createGraphJob {
    my $B = shift;
    my $prevJobId = shift // 0;
    my $urVersion = shift // 0;
    my $separateJob = shift // 0;
    my $lengthHistoOnly = shift // 0;

    my ($smallWidth, $smallHeight) = (700, 315);

    #create information for R to make graphs and then have R make them
    $B->queue($memqueue);
    $B->dependency(0, $prevJobId) if $prevJobId;
    $B->mailEnd();
    $B->setScriptAbortOnError(0); # don't abort on error
    addModule($B, "module load $efiEstMod");
    addModule($B, "module load $efiDbMod");
    if (defined $LegacyGraphs) {
        my $evalueFile = "$outputDir/evalue.tab";
        my $defaultLengthFile = "$outputDir/length.tab";
        $B->resource(1, 1, "50gb");
        addModule($B, "module load $gdMod");
        #addModule($B, "module load $perlMod");
        #addModule($B, "module load $rMod");
        addModule($B, "module load efiest/python_est_1.0");
        addModule($B, "module load Python/3.10.1-IGB-gcc-8.2.0");
        if (not $lengthHistoOnly) {
            # generate the two boxplots, evalue tsv, and edge histogram
            # proxy options for plots are specified in command
            $B->addAction("python ~/EST/visualization/src/process_blast_results.py" .
                          " --blast-output $outputDir/1.out.parquet" .
                          " --job-id $jobId".
                          " --length-plot-filename $outputDir/alignment_length" .
                          " --pident-plot-filename $outputDir/percent_identity" .
                          " --edge-hist-filename $outputDir/number_of_edges" .
                          " --evalue-tab-filename $outputDir/edge.tab" .
                          " --proxies sm:48");
        }
        my %lenFiles = ($lenUniprotFile => {title => "", file => "length_histogram_uniprot"});
        $lenFiles{$lenUniprotFile}->{title} = "UniProt, Full Length" if $urVersion or $domain eq "on";
        $lenFiles{$lenUniprotDomFile} = {title => "UniProt, Domain", file => "length_histogram_uniprot_domain"} if $domain eq "on";
        if ($urVersion) {
            if ($urVersion eq "50+90") {
                $lenFiles{$lenUniref50File} = {title => "UniRef50 Cluster IDs, Full Length", file => "length_histogram_uniref50"};
                $lenFiles{$lenUniref50DomFile} = {title => "UniRef50 Cluster IDs, Domain", file => "length_histogram_uniref50_domain"} if $domain eq "on";
                $lenFiles{$lenUniref90File} = {title => "UniRef90 Cluster IDs, Full Length", file => "length_histogram_uniref90"};
                $lenFiles{$lenUniref90DomFile} = {title => "UniRef90 Cluster IDs, Domain", file => "length_histogram_uniref90_domain"} if $domain eq "on";
            } else {
                $lenFiles{$lenUnirefFile} = {title => "UniRef$urVersion Cluster IDs, Full Length", file => "length_histogram_uniref"};
                $lenFiles{$lenUnirefDomFile} = {title => "UniRef$urVersion Cluster IDs, Domain", file => "length_histogram_uniref_domain"} if $domain eq "on";
            }
        }
        # for every length histogram tsv file, render a histogram (and proxy)
        foreach my $file (keys %lenFiles) {
            my $title = $lenFiles{$file}->{title} ? "\"(" . $lenFiles{$file}->{title} . ")\"" : "\"\"";
            $B->addAction("python ~/EST/visualization/src/plot_length_data.py" .
                          " --lengths $file" .
                          " --job-id $jobId " .
                          " --plot-filename $outputDir/$lenFiles{$file}->{file}" .
                          " --title-extra $title" .
                          " --proxies sm:48");
        }
    }
    if ($separateJob) {
        if ($removeTempFiles) {
            # $B->addAction("rm -rf $blastOutputDir");
            # $B->addAction("rm -rf $fracOutputDir");
            #$B->addAction("rm $blastDb.* $outputDir/format.log"); # Needed for taxonomy
            # $B->addAction("rm $outputDir/sequences.fa.clstr");
            # $B->addAction("rm $outputDir/length_uni*.tab $outputDir/progress $outputDir/edge.tab $outputDir/formatdb.log");
        }
        $B->addAction("touch  $outputDir/1.out.completed");
        $B->addAction("echo 100 > $progressFile");
        $B->jobName("${jobNamePrefix}graphs");
        $B->renderToFile(getRenderFilePath("$scriptDir/graphs.sh"));
        my $graphjob = $S->submit("$scriptDir/graphs.sh");
        chomp $graphjob;
        print "Graph job is:\n $graphjob\n" if not $runSerial;
        my ($graphJobId) = split /\./, $graphjob;
        return $graphJobId;
    } else {
        return 0;
    }
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

