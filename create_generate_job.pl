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
use Getopt::Long;
use POSIX qw(ceil);
use EFI::SchedulerApi;
use EFI::Util qw(usesSlurm getLmod);
use EFI::Config qw(cluster_configure);

use lib "$FindBin::Bin/lib";
use Constants;


my ($np, $queue, $outputDirName, $evalue, $incfrac, $ipro, $pfam, $accessionId, $accessionFile, $taxid);
my ($gene3d, $ssf, $blasthits, $memqueue, $maxsequence, $maxFullFam, $fastaFile, $useFastaHeaders);
my ($seqCountFile, $lengthdif, $noMatchFile, $sim, $multiplexing, $domain, $fraction);
my ($blast, $jobId, $unirefVersion, $noDemuxArg, $cdHitOnly);
my ($scheduler, $dryrun, $oldapps, $LegacyGraphs, $configFile, $removeTempFiles);
my ($minSeqLen, $maxSeqLen, $forceDomain, $domainFamily, $clusterNode, $domainRegion, $excludeFragments);
my $result = GetOptions(
    "np=i"              => \$np,
    "queue=s"           => \$queue,
    "tmp|dir-name=s"    => \$outputDirName,
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
    "memqueue=s"        => \$memqueue,
    "maxsequence=s"     => \$maxsequence,
    "max-full-family=i" => \$maxFullFam,
    "userfasta=s"       => \$fastaFile,
    "use-fasta-headers" => \$useFastaHeaders,
    "seq-count-file=s"  => \$seqCountFile,
    "lengthdif=s"       => \$lengthdif,
    "no-match-file=s"   => \$noMatchFile,
    "sim=s"             => \$sim,
    "multiplex=s"       => \$multiplexing,
    "domain=s"          => \$domain,
    "domain-family=s"   => \$domainFamily,
    "domain-region=s"   => \$domainRegion,
    "force-domain=i"    => \$forceDomain,
    "fraction=i"        => \$fraction,
    "blast=s"           => \$blast,
    "job-id=i"          => \$jobId,
    "no-demux"          => \$noDemuxArg,
    "min-seq-len=i"     => \$minSeqLen,
    "max-seq-len=i"     => \$maxSeqLen,
    "cd-hit=s"          => \$cdHitOnly,     # specify this flag in order to run cd-hit only after getsequence-domain.pl then exit.
    "uniref-version=s"  => \$unirefVersion,
    "scheduler=s"       => \$scheduler,     # to set the scheduler to slurm 
    "dryrun"            => \$dryrun,        # to print all job scripts to STDOUT and not execute the job
    "cluster-node=s"    => \$clusterNode,
    "oldapps"           => \$oldapps,       # to module load oldapps for biocluster2 testing
    "oldgraphs"         => \$LegacyGraphs,  # use the old graphing code
    "remove-temp"       => \$removeTempFiles, # add this flag to remove temp files
    "config=s"          => \$configFile,    # new-style config file
    "exclude-fragments" => \$excludeFragments,
);

die "Environment variables not set properly: missing EFIDB variable" if not exists $ENV{EFIDB};

my $efiEstTools = $ENV{EFIEST};
my $efiEstMod = $ENV{EFIESTMOD};
my $efiDbMod = $ENV{EFIDBMOD};
my $sortdir = '/scratch';

#defaults and error checking for choosing of blast program
if (defined $blast and $blast ne "blast" and $blast ne "blast+" and $blast ne "blast+simple" and $blast ne "diamond" and $blast ne 'diamondsensitive') {
    die "blast program value of $blast is not valid, must be blast, blast+, diamondsensitive, or diamond\n";
} elsif (not defined $blast) {
    $blast = "blast";
}

# Defaults and error checking for splitting sequences into domains
if (defined $domain and $domain ne "off" and $domain ne "on") {
    die "domain value of $domain is not valid, must be either on or off\n";
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

# Working directory must be defined
if (not defined $outputDirName) {
    $outputDirName = "output";
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

$np = ceil($np / 24) if ($blast=~/diamond/);

# Max number of hits for an individual sequence, normally set ot max value
$blasthits = 1000000 if not (defined $blasthits);

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

# We will keep the domain option on
#$domain = "off"     if $unirefVersion and not $forceDomain;

($jobId = $ENV{PWD}) =~ s%^.*/(\d+)/*$%$1% if not $jobId;
$jobId = "" if $jobId =~ /\D/;

$noMatchFile = ""   if not defined $noMatchFile;

my $baseOutputDir = $ENV{PWD};
my $outputDir = "$baseOutputDir/$outputDirName";

my $pythonMod = getLmod("Python/2", "Python");
my $gdMod = getLmod("GD.*Perl", "GD");
my $perlMod = "Perl";
my $rMod = "R";

print "Blast is $blast\n";
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
print "tmpdir is $outputDir\n";
print "evalue is $evalue\n";
print "config is $configFile\n";
print "maxsequence is $maxsequence\n";
print "incfrac is $incfrac\n";
print "seq-count-file is $seqCountFile\n";
print "base output directory is $baseOutputDir\n";
print "output directory is $outputDirName\n";
print "uniref-version is $unirefVersion\n";
print "manualcdhit is $manualCdHit\n";
print "Python module is $pythonMod\n";
print "max-full-family is $maxFullFam\n";
print "cd-hit is $cdHitOnly\n";
print "force-domain is $forceDomain\n";
print "exclude-fragments is $excludeFragments\n";


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
my $lenUnirefFile = "$outputDir/length_uniref.tab"; # full lengths of UR cluster ID sequences
my $lenUnirefDomFile = "$outputDir/length_uniref_domain.tab"; # domain lengths of UR cluster ID sequences
#my $uniprotSeqLenFile = "$outputDir/uniprot_length.tab"; # For UniRef option, this is the lengths of all the sequences in the family not just the seed sequences
#my $unirefClusterSeqLenFile = "$outputDir/uniref_cluster_length.tab"; # For UniRef + Domain option, this is the full lengths of the cluster ID sequences, not accounting for domain.

my $metadataFile = "$outputDir/" . EFI::Config::FASTA_META_FILENAME;

$seqCountFile = "$outputDir/acc_counts" if not $seqCountFile;

# Error checking for user supplied dat and fa files
my $accessionFileOption = "";
my $noMatchFileOption = "";
if (defined $accessionFile and -e $accessionFile) {
    $accessionFile = $baseOutputDir . "/$accessionFile" if not ($accessionFile =~ /^\//i or $accessionFile =~ /^~/);
    $accessionFileOption = "-accession-file $accessionFile";

    $noMatchFile = "$outputDir/" . EFI::Config::NO_ACCESSION_MATCHES_FILENAME if !$noMatchFile;
    $noMatchFile = $baseOutputDir . "/$noMatchFile" if not ($noMatchFile =~ /^\// or $noMatchFile =~ /^~/);
    $noMatchFileOption = "-no-match-file $noMatchFile";

} else {
    $accessionFile = "";
}

my $accessionFileZip = $accessionFile;
if ($accessionFileZip =~ /\.zip$/i) {
    $accessionFile =~ s/\.zip$/.txt/i;
    $accessionFileOption =~ s/\.zip$/.txt/i;
}


#if (defined $fastaFile and -e $fastaFile) { # and -e $metadataFile) {
##} elsif (defined $metadataFile) {
#} else {
#    die "$metadataFile does not exist\n";
##} else {
##    print "this is userdat:$metadataFile:\n";
##    $metadataFile = "";
#}

my $fastaFileOption = "";
if (defined $fastaFile and -e $fastaFile) {
    $fastaFile = "$baseOutputDir/$fastaFile" if not ($fastaFile=~/^\// or $fastaFile=~/^~/);
    $fastaFileOption = "-fasta-file $fastaFile";
    $fastaFileOption = "-use-fasta-headers " . $fastaFileOption if defined $useFastaHeaders;
} else {
    $fastaFile = "";
}

my $fastaFileZip = $fastaFile;
if ($fastaFileZip =~ /\.zip$/i) {
    $fastaFile =~ s/\.zip$/.fasta/i;
    $fastaFileOption =~ s/\.zip$/.fasta/i;
}


# Create tmp directories
mkdir $outputDir;

# Write out the database version to a file
$efiDbMod=~/(\d+)$/;
print "database version is $1 of $efiDbMod\n";
system("echo $1 >$outputDir/database_version");

# Set up the scheduler API so we can work with Torque or Slurm.
my $schedType = "torque";
$schedType = "slurm" if (defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm());
my $usesSlurm = $schedType eq "slurm";
if (defined($oldapps)) {
    $oldapps = $usesSlurm;
} else {
    $oldapps = 0;
}


my $logDir = "$baseOutputDir/log";
mkdir $logDir;
$logDir = "" if not -d $logDir;
my %schedArgs = (type => $schedType, queue => $queue, resource => [1, 1, "35gb"], dryrun => $dryrun);
$schedArgs{output_base_dirpath} = $logDir if $logDir;
$schedArgs{node} = $clusterNode if $clusterNode;
$schedArgs{extra_path} = $config->{cluster}->{extra_path} if $config->{cluster}->{extra_path};
my $S = new EFI::SchedulerApi(%schedArgs);
my $jobNamePrefix = $jobId ? $jobId . "_" : "";
my $progressFile = "$outputDir/progress";

my $scriptDir = "$baseOutputDir/scripts";
mkdir $scriptDir;
$scriptDir = $outputDir if not -d $scriptDir;


########################################################################################################################
# Get sequences and annotations.  This creates fasta and struct.out files.
#
my $B = $S->getBuilder();
$B->resource(1, 1, "5gb");
my $prevJobId;

if ($pfam or $ipro or $ssf or $gene3d or ($fastaFile=~/\w+/ and !$taxid) or $accessionId or $accessionFile) {

    my $maxFullFamOption = $maxFullFam ? "-max-full-fam-ur90 $maxFullFam" : "";

    $B->addAction("module load oldapps") if $oldapps;
    $B->addAction("module load $efiDbMod");
    $B->addAction("module load $efiEstMod");
    $B->addAction("cd $outputDir");
    $B->addAction("unzip -p $fastaFileZip > $fastaFile") if $fastaFileZip =~ /\.zip$/i;
    $B->addAction("unzip -p $accessionFileZip > $accessionFile") if $accessionFileZip =~ /\.zip$/i;
    if ($fastaFile) {
        $B->addAction("dos2unix -q $fastaFile");
        $B->addAction("mac2unix -q $fastaFile");
    }
    if ($accessionFile) {
        $B->addAction("dos2unix -q $accessionFile");
        $B->addAction("mac2unix -q $accessionFile");
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
        "-meta-file $metadataFile",
    );
    
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
        push @args, $domRegionArg if $domFamArg and $domainRegion;
    }

    my $retrScript = "get_sequences_option_";
    if (not $fastaFile and not $accessionFile) {
        $retrScript .= "b.pl";
    } elsif ($fastaFile and $fastaFileOption) {
        $retrScript .= "c.pl";
        push @args, $fastaFileOption;
    } elsif ($accessionFile) {
        $retrScript .= "d.pl";
        push @args, "-uniref-version $unirefVersion" if $unirefVersion and not($pfam or $ipro or $ssf or $gene3d); # Don't add this arg if the family is included, because the arg is already included in the family section
        push @args, $accessionFileOption;
        push @args, $noMatchFileOption;
    }

    push @args, "-exclude-fragments" if $excludeFragments;

    $B->addAction("$efiEstTools/$retrScript " . join(" ", @args));

    my @lenUniprotArgs = ("-struct $metadataFile", "-config $configFile");
    push @lenUniprotArgs, "-output $lenUniprotFile";
    push @lenUniprotArgs, "-expand-uniref" if $unirefVersion;
    $B->addAction("$efiEstTools/get_lengths_from_anno.pl " . join(" ", @lenUniprotArgs));
    
    if ($unirefVersion) {
        my @lenUnirefArgs = ("-struct $metadataFile", "-config $configFile");
        push @lenUnirefArgs, "-output $lenUnirefFile";
        $B->addAction("$efiEstTools/get_lengths_from_anno.pl " . join(" ", @lenUnirefArgs));
    }

    # Annotation retrieval (getannotations.pl) now happens in the SNN/analysis step.

    $B->addAction("echo 33 > $progressFile");
    $B->jobName("${jobNamePrefix}initial_import");
    $B->renderToFile("$scriptDir/initial_import.sh");

    # Submit and keep the job id for next dependancy
    my $importjob = $S->submit("$scriptDir/initial_import.sh");
    chomp $importjob;

    print "import job is:\n $importjob\n";
    ($prevJobId) = split(/\./, $importjob);

# Tax id code is different, so it is exclusive
} elsif ($taxid) {

    $B->addAction("module load oldapps") if $oldapps;
    $B->addAction("module load $efiDbMod");
    $B->addAction("module load $efiEstMod");
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
    $B->renderToFile("$scriptDir/initial_import.sh");

    my $importjob = $S->submit("$scriptDir/initial_import.sh");
    chomp $importjob;

    print "import job is:\n $importjob\n";
    ($prevJobId) = split /\./, $importjob;
} else {
    die "Error Submitting Import Job\nYou cannot mix ipro, pfam, ssf, and gene3d databases with taxid\n";
}


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
    $B->addAction("module load oldapps") if $oldapps;
    $B->addAction("module load $efiDbMod");
    $B->addAction("module load $efiEstMod");
    #$B->addAction("module load blast");
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
    $B->renderToFile("$scriptDir/cdhit.sh");
    my $cdhitjob = $S->submit("$scriptDir/cdhit.sh");
    chomp $cdhitjob;
    print "CD-HIT job is:\n $cdhitjob\n";
    exit;
}

$B->resource(1, 1, "10gb");

$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiDbMod");
$B->addAction("module load $efiEstMod");
#$B->addAction("module load blast");
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
$B->renderToFile("$scriptDir/multiplex.sh");

my $muxjob = $S->submit("$scriptDir/multiplex.sh");
chomp $muxjob;
print "mux job is:\n $muxjob\n";
($prevJobId) = split /\./, $muxjob;


########################################################################################################################
# Break sequenes.fa into parts so we can run blast in parallel.
#
$B = $S->getBuilder();
$B->resource(1, 1, "5gb");

$B->dependency(0, $prevJobId);
$B->addAction("mkdir -p $fracOutputDir");
$B->addAction("$efiEstTools/split_fasta.pl -parts $np -tmp $fracOutputDir -source $filtSeqFile");
$B->jobName("${jobNamePrefix}fracfile");
$B->renderToFile("$scriptDir/fracfile.sh");

my $fracfilejob = $S->submit("$scriptDir/fracfile.sh");
chomp $fracfilejob;
print "fracfile job is:\n $fracfilejob\n";
($prevJobId) = split /\./, $fracfilejob;


########################################################################################################################
# Make the blast database and put it into the temp directory
#
$B = $S->getBuilder();

$B->dependency(0, $prevJobId);
$B->resource(1, 1, "5gb");
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiDbMod");
$B->addAction("module load $efiEstMod");
$B->addAction("cd $outputDir");
if ($blast eq 'diamond' or $blast eq 'diamondsensitive') {
    $B->addAction("module load diamond");
    $B->addAction("diamond makedb --in $filtSeqFilename -d database");
} else {
    $B->addAction("formatdb -i $filtSeqFilename -n database -p T -o T ");
}
$B->jobName("${jobNamePrefix}createdb");
$B->renderToFile("$scriptDir/createdb.sh");

my $createdbjob = $S->submit("$scriptDir/createdb.sh");
chomp $createdbjob;
print "createdb job is:\n $createdbjob\n";
($prevJobId) = split /\./, $createdbjob;


########################################################################################################################
# Generate job array to blast files from fracfile step
#
my $blastFinalFile = "$outputDir/blastfinal.tab";

$B = $S->getBuilder();
mkdir $blastOutputDir;

$B->setScriptAbortOnError(0); # Disable SLURM aborting on errors, since we want to catch the BLAST error and report it to the user nicely
$B->jobArray("1-$np") if $blast eq "blast";
$B->dependency(0, $prevJobId);
$B->resource(1, 1, "5gb");
$B->resource(1, 24, "14G") if $blast =~ /diamond/i;
$B->resource(1, 24, "14G") if $blast =~ /blast\+/i;

$B->addAction("export BLASTDB=$outputDir");
#$B->addAction("module load oldapps") if $oldapps;
#$B->addAction("module load blast+");
#$B->addAction("blastp -query  $fracOutputDir/fracfile-{JOB_ARRAYID}.fa  -num_threads 2 -db database -gapopen 11 -gapextend 1 -comp_based_stats 2 -use_sw_tback -outfmt \"6 qseqid sseqid bitscore evalue qlen slen length qstart qend sstart send pident nident\" -num_descriptions 5000 -num_alignments 5000 -out $blastOutputDir/blastout-{JOB_ARRAYID}.fa.tab -evalue $evalue");
$B->addAction("module load $efiDbMod");
$B->addAction("module load $efiEstMod");
if ($blast eq "blast") {
    $B->addAction("module load oldapps") if $oldapps;
    #$B->addAction("module load blast");
    $B->addAction("blastall -p blastp -i $fracOutputDir/fracfile-{JOB_ARRAYID}.fa -d $outputDir/database -m 8 -e $evalue -b $blasthits -o $blastOutputDir/blastout-{JOB_ARRAYID}.fa.tab");
} elsif ($blast eq "blast+") {
    $B->addAction("module load oldapps") if $oldapps;
    $B->addAction("module load BLAST+");
    $B->addAction("blastp -query $filtSeqFile -num_threads $np -db $outputDir/database -gapopen 11 -gapextend 1 -comp_based_stats 2 -use_sw_tback -outfmt \"6\" -max_hsps 1 -num_descriptions $blasthits -num_alignments $blasthits -out $blastFinalFile -evalue $evalue");
} elsif ($blast eq "blast+simple") {
    $B->addAction("module load oldapps") if $oldapps;
    $B->addAction("module load BLAST+");
    $B->addAction("blastp -query $filtSeqFile -num_threads $np -db $outputDir/database -outfmt \"6\" -num_descriptions $blasthits -num_alignments $blasthits -out $blastFinalFile -evalue $evalue");
} elsif ($blast eq "diamond") {
    $B->addAction("module load oldapps") if $oldapps;
    $B->addAction("module load DIAMOND");
    $B->addAction("diamond blastp -p 24 -e $evalue -k $blasthits -C $blasthits -q $filtSeqFile -d $outputDir/database -a $blastOutputDir/blastout.daa");
    $B->addAction("diamond view -o $blastFinalFile -f tab -a $blastOutputDir/blastout.daa");
} elsif ($blast eq "diamondsensitive") {
    $B->addAction("module load oldapps") if $oldapps;
    $B->addAction("module load DIAMOND");
    $B->addAction("diamond blastp --sensitive -p 24 -e $evalue -k $blasthits -C $blasthits -q $fracOutputDir/fracfile-{JOB_ARRAYID}.fa -d $outputDir/database -a $blastOutputDir/blastout.daa");
    $B->addAction("diamond view -o $blastFinalFile -f tab -a $blastOutputDir/blastout.daa");
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
$B->renderToFile("$scriptDir/blastqsub.sh");

$B->jobArray("");
my $blastjob = $S->submit("$scriptDir/blastqsub.sh");
chomp $blastjob;
print "blast job is:\n $blastjob\n";
($prevJobId) = split /\./, $blastjob;


########################################################################################################################
# Join all the blast outputs back together
#
$B = $S->getBuilder();

$B->resource(1, 1, "5gb");
$B->dependency(1, $prevJobId);
$B->addAction("cat $blastOutputDir/blastout-*.tab |grep -v '#'|cut -f 1,2,3,4,12 >$blastFinalFile")
    if $blast eq "blast";
$B->addAction("SZ=`stat -c%s $blastFinalFile`");
$B->addAction("if [[ \$SZ == 0 ]]; then");
$B->addAction("    echo \"BLAST Failed. Check input file.\"");
$B->addAction("    touch $outputDir/blast.failed");
$B->addAction("    exit 1");
$B->addAction("fi");
$B->jobName("${jobNamePrefix}catjob");
$B->renderToFile("$scriptDir/catjob.sh");
my $catjob = $S->submit("$scriptDir/catjob.sh");
chomp $catjob;
print "Cat job is:\n $catjob\n";
($prevJobId) = split /\./, $catjob;


########################################################################################################################
# Remove like vs like and reverse matches
#
$B = $S->getBuilder();

$B->queue($memqueue);
$B->resource(1, 1, "350gb");
$B->dependency(0, $prevJobId);
#$B->addAction("mv $blastFinalFile $outputDir/unsorted.blastfinal.tab");
$B->addAction("$efiEstTools/alphabetize.pl -in $blastFinalFile -out $outputDir/alphabetized.blastfinal.tab -fasta $filtSeqFile");
$B->addAction("sort -T $sortdir -k1,1 -k2,2 -k5,5nr -t\$\'\\t\' $outputDir/alphabetized.blastfinal.tab > $outputDir/sorted.alphabetized.blastfinal.tab");
$B->addAction("$efiEstTools/blastreduce-alpha.pl -blast $outputDir/sorted.alphabetized.blastfinal.tab -out $outputDir/unsorted.1.out");
$B->addAction("sort -T $sortdir -k5,5nr -t\$\'\\t\' $outputDir/unsorted.1.out >$outputDir/1.out");
$B->addAction("echo 67 > $progressFile");
$B->jobName("${jobNamePrefix}blastreduce");
$B->renderToFile("$scriptDir/blastreduce.sh");

my $blastreducejob = $S->submit("$scriptDir/blastreduce.sh");
chomp $blastreducejob;
print "Blastreduce job is:\n $blastreducejob\n";

($prevJobId) = split /\./, $blastreducejob;


########################################################################################################################
# If multiplexing is on, demultiplex sequences back so all are present
#
$B = $S->getBuilder();

$B->dependency(0, $prevJobId);
$B->resource(1, 1, "5gb");
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiDbMod");
$B->addAction("module load $efiEstMod");
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
$B->renderToFile("$scriptDir/demux.sh");

my $demuxjob = $S->submit("$scriptDir/demux.sh");
chomp $demuxjob;
print "Demux job is:\n $demuxjob\n";
($prevJobId) = split /\./, $demuxjob;



########################################################################################################################
# Compute convergence ratio
#
$B = $S->getBuilder();
$B->dependency(0, $prevJobId);
$B->resource(1, 1, "5gb");
        
$B->addAction("$efiEstTools/calc_blast_stats.pl -edge-file $outputDir/1.out -seq-file $allSeqFile -unique-seq-file $filtSeqFile -seq-count-output $seqCountFile");
$B->jobName("${jobNamePrefix}conv_ratio");
$B->renderToFile("$scriptDir/conv_ratio.sh");
my $convRatioJob = $S->submit("$scriptDir/conv_ratio.sh");
chomp $convRatioJob;
print "Convergence ratio job is:\n $convRatioJob\n";
my @convRatioJobLine=split /\./, $convRatioJob;



########################################################################################################################
# Removed in favor of R, comments kept in case someone ever wants to use the pure perl solution
=pod Start comment
#submit the quartiles scripts, should not run until filterjob is finished
#nothing else depends on this scipt

$B->queue($memqueue);
$B->dependency(0, $prevJobId);
$B->addAction("module load oldapps\n" if $oldapps);
$B->addAction("module load $efiDbMod");
$B->addAction("module load $efiEstMod");
$B->addAction("$efiEstTools/quart-align.pl -blastout $outputDir/1.out -align $outputDir/alignment_length.png");
$B->renderToFile("$scriptDir/quartalign.sh");

my $quartalignjob = $S->submit("$scriptDir/quartalign.sh");
chomp $quartalignjob;
print "Quartile Align job is:\n $quartalignjob\n";


$B->queue($memqueue);
$B->dependency(0, $prevJobId);
$B->addAction("#PBS -m e");
$B->addAction("module load oldapps\n" if $oldapps);
$B->addAction("module load $efiDbMod");
$B->addAction("module load $efiEstMod");
$B->addAction("$efiEstTools/quart-perid.pl -blastout $outputDir/1.out -pid $outputDir/percent_identity.png");
$B->renderToFile("$scriptDir/quartpid.sh");

my $quartpidjob = $S->submit("$scriptDir/quartpid.sh");
chomp $quartpidjob;
print "Quartiles Percent Identity job is:\n $quartpidjob\n";


$B->queue($memqueue);
$B->dependency(0, $prevJobId);
$B->addAction("module load oldapps\n" if $oldapps);
$B->addAction("module load $efiDbMod");
$B->addAction("module load $efiEstMod");
$B->addAction("$efiEstTools/simplegraphs.pl -blastout $outputDir/1.out -edges $outputDir/number_of_edges.png -fasta $allSeqFile -lengths $outputDir/length_histogram.png -incfrac $incfrac");
$B->renderToFile("$scriptDir/simplegraphs.sh");

my $simplegraphjob = $S->submit("$scriptDir/simplegraphs.sh");
chomp $simplegraphjob;
print "Simplegraphs job is:\n $simplegraphjob\n";
=cut end comment


########################################################################################################################
# Create information for R to make graphs and then have R make them
#
$B = $S->getBuilder();

my ($smallWidth, $smallHeight) = (700, 315);

#create information for R to make graphs and then have R make them
$B->queue($memqueue);
$B->dependency(0, $prevJobId);
$B->mailEnd();
$B->setScriptAbortOnError(0); # don't abort on error
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
if (defined $LegacyGraphs) {
    my $evalueFile = "$outputDir/evalue.tab";
    my $defaultLengthFile = "$outputDir/length.tab";
    $B->resource(1, 1, "50gb");
    $B->addAction("module load $gdMod");
    $B->addAction("module load $perlMod");
    $B->addAction("module load $rMod");
    $B->addAction("mkdir -p $outputDir/rdata");
    # Lengths are retrieved in a previous step.
    $B->addAction("$efiEstTools/Rgraphs.pl -blastout $outputDir/1.out -rdata  $outputDir/rdata -edges  $outputDir/edge.tab -fasta  $allSeqFile -incfrac $incfrac -evalue-file $evalueFile");
    $B->addAction("FIRST=`ls $outputDir/rdata/perid* 2>/dev/null | head -1`");
    $B->addAction("if [ -z \"\$FIRST\" ]; then");
    $B->addAction("    echo \"Graphs failed, there were no edges. Continuing without graphs.\"");
    $B->addAction("    touch $outputDir/graphs.failed");
    $B->addAction("    touch  $outputDir/1.out.completed");
    $B->addAction("    exit 0 #Exit with no error");
    $B->addAction("fi");
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
    my %lenFiles = ($lenUniprotFile => {title => "", file => "length_histogram_uniprot"});
    $lenFiles{$lenUniprotFile}->{title} = "UniProt, Full Length" if $unirefVersion or $domain eq "on";
    $lenFiles{$lenUniprotDomFile} = {title => "UniProt, Domain", file => "length_histogram_uniprot_domain"} if $domain eq "on";
    $lenFiles{$lenUnirefFile} = {title => "UniRef$unirefVersion Cluster IDs, Full Length", file => "length_histogram_uniref"} if $unirefVersion;
    $lenFiles{$lenUnirefDomFile} = {title => "UniRef$unirefVersion Cluster IDs, Domain", file => "length_histogram_uniref_domain"} if $unirefVersion and $domain eq "on";
    foreach my $file (keys %lenFiles) {
        my $title = $lenFiles{$file}->{title} ? "\"(" . $lenFiles{$file}->{title} . ")\"" : "\"\"";
        $B->addAction("Rscript $efiEstTools/Rgraphs/hist-length.r legacy $file $outputDir/$lenFiles{$file}->{file}.png $jobId $title");
        $B->addAction("Rscript $efiEstTools/Rgraphs/hist-length.r legacy $file $outputDir/$lenFiles{$file}->{file}_sm.png $jobId $title $smallWidth $smallHeight");
    }
} else {
    $B->addAction("module load $pythonMod");
    $B->addAction("$efiEstTools/R-hdf-graph.py -b $outputDir/1.out -f $outputDir/rdata.hdf5 -a $allSeqFile -i $incfrac");
    $B->addAction("Rscript $efiEstTools/Rgraphs/quart-align.r hdf5 $outputDir/rdata.hdf5 $outputDir/alignment_length.png $jobId");
    $B->addAction("Rscript $efiEstTools/Rgraphs/quart-align.r hdf5 $outputDir/rdata.hdf5 $outputDir/alignment_length_sm.png $jobId $smallWidth $smallHeight");
    $B->addAction("Rscript $efiEstTools/Rgraphs/quart-perid.r hdf5 $outputDir/rdata.hdf5 $outputDir/percent_identity.png $jobId");
    $B->addAction("Rscript $efiEstTools/Rgraphs/quart-perid.r hdf5 $outputDir/rdata.hdf5 $outputDir/percent_identity_sm.png $jobId $smallWidth $smallHeight");
    $B->addAction("Rscript $efiEstTools/Rgraphs/hist-length.r hdf5 $outputDir/rdata.hdf5 $outputDir/length_histogram.png $jobId");
    $B->addAction("Rscript $efiEstTools/Rgraphs/hist-length.r hdf5 $outputDir/rdata.hdf5 $outputDir/length_histogram_sm.png $jobId $smallWidth $smallHeight");
    $B->addAction("Rscript $efiEstTools/Rgraphs/hist-edges.r hdf5 $outputDir/rdata.hdf5 $outputDir/number_of_edges.png $jobId");
    $B->addAction("Rscript $efiEstTools/Rgraphs/hist-edges.r hdf5 $outputDir/rdata.hdf5 $outputDir/number_of_edges_sm.png $jobId $smallWidth $smallHeight");
}
$B->addAction("touch  $outputDir/1.out.completed");
if ($removeTempFiles) {
    $B->addAction("rm $outputDir/alphabetized.blastfinal.tab $blastFinalFile $outputDir/sorted.alphabetized.blastfinal.tab $outputDir/unsorted.1.out $outputDir/mux.out");
    $B->addAction("rm $blastOutputDir/blastout-*.tab");
    $B->addAction("rm $fracOutputDir/fracfile-*.fa");
}
$B->addAction("echo 100 > $progressFile");
$B->jobName("${jobNamePrefix}graphs");
$B->renderToFile("$scriptDir/graphs.sh");

my $graphjob = $S->submit("$scriptDir/graphs.sh");
chomp $graphjob;
print "Graph job is:\n $graphjob\n";


