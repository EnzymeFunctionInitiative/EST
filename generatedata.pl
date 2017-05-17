#!/usr/bin/env perl

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
#       blast-qsub.sh           job array of np elements that blasts each fraction of sequences.fa against database of sequences.fa
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

use FindBin;
use Cwd qw(abs_path);
use File::Basename;
use lib "$FindBin::Bin/lib";
use Getopt::Long;
use POSIX qw(ceil);
use Biocluster::SchedulerApi;
use Biocluster::Util qw(usesSlurm);
use Biocluster::Config;

$result = GetOptions(
    "np=i"              => \$np,
    "queue=s"           => \$queue,
    "tmp=s"             => \$tmpdir,
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
#    "userdat=s"         => \$userHeaderFile,
    "userfasta=s"       => \$fastaFile,
    "use-fasta-headers" => \$useFastaHeaders,
    "lengthdif=f"       => \$lengthdif,
    "sim=f"             => \$sim,
    "multiplex=s"       => \$multiplexing,
    "domain=s"          => \$domain,
    "fraction=i"        => \$fraction,
    "blast=s"           => \$blast,
    "scheduler=s"       => \$scheduler,     # to set the scheduler to slurm 
    "dryrun"            => \$dryrun,        # to print all job scripts to STDOUT and not execute the job
    "oldapps"           => \$oldapps,       # to module load oldapps for biocluster2 testing
    "config=s"          => \$configFile,        # new-style config file
);

die "Environment variables not set properly: missing EFIDB variable" if not exists $ENV{EFIDB};

my $toolpath = $ENV{EFIEST};
my $efiestmod = $ENV{EFIDBMOD};
my $efidbmod = $efiestmod;
my $sortdir = '/state/partition1';

#defaults and error checking for choosing of blast program
if (defined $blast and $blast ne "blast" and $blast ne "blast+" and $blast ne "diamond" and $blast ne 'diamondsensitive') {
    die "blast program value of $blast is not valid, must be blast, blast+, diamondsensitive, or diamond\n";
} elsif (not defined $blast) {
    $blast = "blast";
}

# Defaults and error checking for splitting sequences into domains
if (defined $domain and $domain ne "off" and $domain ne "on") {
    die "domain value of $domain is not valid, must be either on or off\n";
} elsif (not defined $domain) {
    $domain = "off";
}

# Defaults for fraction of sequences to fetch
if (defined $fraction and $fraction !~ /^\d+$/ and $fraction <= 0) {
    die "if fraction is defined, it must be greater than zero\n";
} elsif (not defined $fraction) {
    $fraction=1;
}


# Defaults and error checking for multiplexing
if ($multiplexing eq "on") {
    if (defined $lengthdif and $lengthdif !~ /\d*\.\d+/) {
        die "lengthdif must be in a format like 0.9\n";
    } elsif (not defined $lengthdif) {
        $lengthdif=1;
    }
    if (defined $sim and $sim !~ /\d*\.\d+/) {
        die "sim must be in a format like 0.9\n";
    } elsif (not defined $sim) {
        $sim=1;
    }
} elsif ($multiplexing eq "off") {
    if (defined $lengthdif and $lengthdif !~ /\d*\.\d+/) {
        die "lengthdif must be in a format like 0.9\n";
    } elsif (not defined $lengthdif) {
        $lengthdif=1;
    }
    if (defined $sim and $sim !~ /\d*\.\d+/) {
        die "sim must be in a format like 0.9\n";
    } elsif (not defined $sim) {
        $sim=1;
    } 
} elsif (!(defined $multiplexing)) {
    $multiplexing = "on";
    if (defined $lengthdif and $lengthdif !~ /\d*\.\d+/) {
        die "lengthdif must be in a format like 0.9\n";
    } elsif (not defined $lengthdif) {
        $lengthdif=1;
    }
    if (defined $sim and $sim !~ /\d*\.\d+/) {
        die "sim must be in a format like 0.9\n";
    } elsif (not defined $sim) {
        $sim=1;
    }
} else {
    die "valid variables for multiplexing are either on or off\n";
}


# At least one of tehse inputs are required to get sequences for the program
unless (defined $fastaFile or defined $ipro or defined $pfam or defined $taxid or defined $ssf or defined $gene3d or
        defined $accessionId or defined $accessionFile) {
    die "You must spedify the -fasta, -ipro, -taxid, -pfam, -accession-id, or -useraccession arguments\n";
}

# You also have to specify the number of processors for blast
unless (defined $np) {
    die "You must spedify the -np variable\n";
}

# Default queues
unless (defined $queue) {
    print "-queue not specified, using default\n";
    $queue = "efi";
}
unless (defined $memqueue) {
    print "-memqueue not specifiied, using default\n";
    $memqueue = "efi-mem";
}

# Working directory must be defined
unless (defined $tmpdir) {
    die "You must spedify the -tmp variable\n";
}

# Default e value must also be set for blast, default set if not specified
unless (defined $evalue) {
    print "-evalue not specified, using default of 5\n";
    $evalue = "1e-5";
} else {
    if ( $evalue =~ /^\d+$/ ) { 
        $evalue = "1e-$evalue";
    }
}

if (not defined $configFile or not -f $configFile) {
    if (exists $ENV{EFICONFIG}) {
        $configFile = $ENV{EFICONFIG};
    } else {
        die "--config file parameter is not specified.  module load efiest_v2 should take care of this.";
    }
}


$np = ceil($np / 24) if ($blast=~/diamond/);

# Max number of hits for an individual sequence, normally set ot max value
$blasthits = 1000000 unless (defined $blasthits);

# Wet input families to zero if they are not specified
$pfam = 0           unless (defined $pfam);
$ipro = 0           unless (defined $ipro);
$taxid = 0          unless (defined $taxid);
$gene3d = 0         unless (defined $gene3d);
$ssf = 0            unless (defined $ssf);
$accessionId = 0    unless (defined $accessionId);

# Default values for bandpass filter, 0,0 disables it, which is the default
$maxlen = 0         unless (defined $maxlen);
$minlen = 0         unless (defined $minlen);

# Maximum number of sequences to process, 0 disables it
$maxsequence = 0    unless (defined $maxsequence);

# Fraction of sequences to include in graphs, reduces effects of outliers
unless (defined $incfrac) {
    print "-incfrac not specified, using default of 0.99\n";
    $incfrac=0.99;
}

print "Blast is $blast\n";
print "domain is $domain\n";
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
print "np is $np\n";
print "queue is $queue\n";
print "memqueue is $memqueue\n";
print "tmpdir is $tmpdir\n";
print "evalue is $evalue\n";
print "config is $configFile\n";
print "maxlen is $maxlen\n";
print "minlen is $minlen\n";
print "maxsequence is $maxsequence\n";
print "incfrac is $incfrac\n";


my $userHeaderFile = "";

# Error checking for user supplied dat and fa files
my $noMatchFile = "";
if (defined $accessionFile and -e $accessionFile) {
    $accessionFile = $ENV{PWD} . "/$accessionFile" unless ($accessionFile =~ /^\//i or $accessionFile =~ /^~/);
    $userHeaderFile = dirname($accessionFile) . "/" . Biocluster::Config::FASTA_META_FILENAME;
    $accessionFile = "-accession-file $accessionFile";

    $noMatchFile = "$tmpdir/" . Biocluster::Config::NO_ACCESSION_MATCHES_FILENAME;
    $noMatchFile = $ENV{PWD} . "/$noMatchFile" unless ($noMatchFile =~ /^\// or $noMatchFile =~ /^~/);
    $noMatchFile = "-no-match-file $noMatchFile";

    $userHeaderFile = "-meta-file $userHeaderFile";
} elsif (defined $accessionFile) {
    die "accession file $accessionFile does not exist\n";
} else {
    $accessionFile = "";
}


#if (defined $fastaFile and -e $fastaFile) { # and -e $userHeaderFile) {
##} elsif (defined $userHeaderFile) {
#} else {
#    die "$userHeaderFile does not exist\n";
##} else {
##    print "this is userdat:$userHeaderFile:\n";
##    $userHeaderFile = "";
#}

if (defined $fastaFile and -e $fastaFile) {
    $fastaFile = $ENV{PWD}."/$fastaFile" unless ($fastaFile=~/^\// or $fastaFile=~/^~/);
    $userHeaderFile = dirname($fastaFile) . "/" . Biocluster::Config::FASTA_META_FILENAME;
    $fastaFile = "-fasta-file $fastaFile";
    $fastaFile .= " -use-fasta-headers" if defined $useFastaHeaders;
    $userHeaderFile = "-meta-file $userHeaderFile";
} elsif (defined $fastaFile) {
    die "$fastaFile does not exist\n";
} else {
    $fastaFile = "";
}


# Create tmp directories
mkdir $tmpdir;

# Write out the database version to a file
$efidbmod=~/(\d+)$/;
print "database version is $1 of $efidbmod\n";
system("echo $1 >$tmpdir/database_version");

# Set up the scheduler API so we can work with Torque or Slurm.
my $schedType = "torque";
$schedType = "slurm" if (defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm());
my $usesSlurm = $schedType eq "slurm";
if (defined($oldapps)) {
    $oldapps = $usesSlurm;
} else {
    $oldapps = 0;
}


my $S = new Biocluster::SchedulerApi(type => $schedType, queue => $queue, resource => [1, 1], dryrun => $dryrun);


########################################################################################################################
# Get sequences and annotations.  This creates fasta and struct.out files.
#
my $B = $S->getBuilder();
if ($pfam or $ipro or $ssf or $gene3d or ($fastaFile=~/\w+/ and !$taxid) or $accessionId or $accessionFile) {


    $B->addAction("module load oldapps") if $oldapps;
    $B->addAction("module load $efiestmod");
    $B->addAction("cd $ENV{PWD}/$tmpdir");
    $B->addAction("which perl");
    $B->addAction("$toolpath/getsequence-domain.pl -domain $domain $fastaFile $userHeaderFile -ipro $ipro -pfam $pfam -ssf $ssf -gene3d $gene3d -accession-id $accessionId $accessionFile $noMatchFile -out ".$ENV{PWD}."/$tmpdir/allsequences.fa -maxsequence $maxsequence -fraction $fraction -accession-output ".$ENV{PWD}."/$tmpdir/accession.txt -config=$configFile");
    $B->addAction("$toolpath/getannotations.pl -out ".$ENV{PWD}."/$tmpdir/struct.out -fasta ".$ENV{PWD}."/$tmpdir/allsequences.fa $userHeaderFile -config=$configFile");
    $B->renderToFile("$tmpdir/initial_import.sh");

    # Submit and keep the job id for next dependancy
    $importjob = $S->submit("$ENV{PWD}/$tmpdir/initial_import.sh");

    print "import job is:\n $importjob";
    @importjobline=split /\./, $importjob;

# Tax id code is different, so it is exclusive
} elsif ($taxid) {

    $B->addAction("module load oldapps") if $oldapps;
    $B->addAction("module load $efiestmod");
    $B->addAction("cd $ENV{PWD}/$tmpdir");
    $B->addAction("$toolpath/getseqtaxid.pl -fasta allsequences.fa -struct struct.out -taxid $taxid -config=$configFile");
    if ($fastaFile=~/\w+/) {
        $fastaFile=~s/^-userfasta //;
        $B->addAction("cat $fastaFile >> allsequences.fa");
    }
    #TODO: handle the header file for this case....
    if ($userHeaderFile=~/\w+/) {
        $userHeaderFile=~s/^-userdat //;
        $B->addAction("cat $userHeaderFile >> struct.out");
    }
    $B->renderToFile("$tmpdir/initial_import.sh");

    $importjob = $S->submit("$ENV{PWD}/$tmpdir/initial_import.sh");

    print "import job is:\n $importjob";
    @importjobline=split /\./, $importjob;
} else {
    die "Error Submitting Import Job\n$importjob\nYou cannot mix ipro, pfam, ssf, and gene3d databases with taxid\n";
}


#######################################################################################################################
# Try to reduce the number of sequences to speed up computation.
# If multiplexing is on, run an initial cdhit to get a reduced set of "more" unique sequences.
# If not, just copy allsequences.fa to sequences.fa so next part of program is set up right.
#
$B = $S->getBuilder();
$B->dependency(0, @importjobline[0]);
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiestmod");
#$B->addAction("module load blast");
$B->addAction("cd $ENV{PWD}/$tmpdir");
if ($multiplexing eq "on") {
    $B->addAction("cd-hit -c $sim -s $lengthdif -i $ENV{PWD}/$tmpdir/allsequences.fa -o $ENV{PWD}/$tmpdir/sequences.fa");
} else {
    $B->addAction("cp $ENV{PWD}/$tmpdir/allsequences.fa $ENV{PWD}/$tmpdir/sequences.fa");
}
$B->renderToFile("$tmpdir/multiplex.sh");

$muxjob = $S->submit("$ENV{PWD}/$tmpdir/multiplex.sh");
print "mux job is:\n $muxjob";
@muxjobline=split /\./, $muxjob;


########################################################################################################################
# Break sequenes.fa into parts so we can run blast in parallel.
#
$B = $S->getBuilder();

$B->dependency(0, @muxjobline[0]);
$B->addAction("$toolpath/splitfasta.pl -parts $np -tmp ".$ENV{PWD}."/$tmpdir -source $ENV{PWD}/$tmpdir/sequences.fa");
$B->renderToFile("$tmpdir/fracfile.sh");

$fracfilejob = $S->submit("$tmpdir/fracfile.sh");
print "fracfile job is:\n $fracfilejob";
@fracfilejobline=split /\./, $fracfilejob;


########################################################################################################################
# Make the blast database and put it into the temp directory
#
$B = $S->getBuilder();

$B->dependency(0, @fracfilejobline[0]);
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiestmod");
$B->addAction("cd $ENV{PWD}/$tmpdir");
if ($blast eq 'diamond' or $blast eq 'diamondsensitive') {
    $B->addAction("module load diamond");
    $B->addAction("diamond makedb --in sequences.fa -d database");
} else {
    $B->addAction("formatdb -i sequences.fa -n database -p T -o T ");
}
$B->renderToFile("$tmpdir/createdb.sh");

$createdbjob = $S->submit("$tmpdir/createdb.sh");
print "createdb job is:\n $createdbjob";
@createdbjobline=split /\./, $createdbjob;


########################################################################################################################
# Generate job array to blast files from fracfile step
#
$B = $S->getBuilder();

$B->jobArray("1-$np");
$B->dependency(0, @createdbjobline[0]);
if ($blast =~ /diamond/){
    $B->resource(1, 24);
}
$B->addAction("export BLASTDB=$ENV{PWD}/$tmpdir");
#$B->addAction("module load oldapps") if $oldapps;
#$B->addAction("module load blast+");
#$B->addAction("blastp -query  $ENV{PWD}/$tmpdir/fracfile-\${PBS_ARRAYID}.fa  -num_threads 2 -db database -gapopen 11 -gapextend 1 -comp_based_stats 2 -use_sw_tback -outfmt \"6 qseqid sseqid bitscore evalue qlen slen length qstart qend sstart send pident nident\" -num_descriptions 5000 -num_alignments 5000 -out $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.tab -evalue $evalue");
$B->addAction("module load $efiestmod");
if ($blast eq "blast") {
    $B->addAction("module load oldapps") if $oldapps;
    #$B->addAction("module load blast");
    $B->addAction("blastall -p blastp -i $ENV{PWD}/$tmpdir/fracfile-\${PBS_ARRAYID}.fa -d $ENV{PWD}/$tmpdir/database -m 8 -e $evalue -b $blasthits -o $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.tab");
} elsif ($blast eq "blast+") {
    $B->addAction("module load oldapps") if $oldapps;
    $B->addAction("module load blast+");
    $B->addAction("blastp -query  $ENV{PWD}/$tmpdir/fracfile-\${PBS_ARRAYID}.fa  -num_threads 2 -db database -gapopen 11 -gapextend 1 -comp_based_stats 2 -use_sw_tback -outfmt \"6\" -max_hsps 1 -num_descriptions $blasthits -num_alignments $blasthits -out $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.tab -evalue $evalue");
} elsif ($blast eq "diamond") {
    $B->addAction("module load oldapps") if $oldapps;
    $B->addAction("module load diamond");
    $B->addAction("diamond blastp -p 24 -e $evalue -k $blasthits -C $blasthits -q $ENV{PWD}/$tmpdir/fracfile-\${PBS_ARRAYID}.fa -d $ENV{PWD}/$tmpdir/database -a $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.daa");
    $B->addAction("diamond view -o $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.tab -f tab -a $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.daa");
} elsif ($blast eq "diamondsensitive") {
    $B->addAction("module load oldapps") if $oldapps;
    $B->addAction("module load diamond");
    $B->addAction("diamond blastp --sensitive -p 24 -e $evalue -k $blasthits -C $blasthits -q $ENV{PWD}/$tmpdir/fracfile-\${PBS_ARRAYID}.fa -d $ENV{PWD}/$tmpdir/database -a $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.daa");
    $B->addAction("diamond view -o $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.tab -f tab -a $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.daa");
} else {
    die "Blast control not set properly.  Can only be blast, blast+, or diamond.\n";
}
$B->renderToFile("$tmpdir/blast-qsub.sh");

$B->jobArray("");
$blastjob = $S->submit("$tmpdir/blast-qsub.sh");
print "blast job is:\n $blastjob";
@blastjobline=split /\./, $blastjob;


########################################################################################################################
# Join all the blast outputs back together
#
$B = $S->getBuilder();

$B->dependency(1, @blastjobline[0]); 
$B->addAction("cat $ENV{PWD}/$tmpdir/blastout-*.tab |grep -v '#'|cut -f 1,2,3,4,12 >$ENV{PWD}/$tmpdir/blastfinal.tab");
#$B->addAction("rm  $ENV{PWD}/$tmpdir/blastout-*.tab");
#$B->addAction("rm  $ENV{PWD}/$tmpdir/fracfile-*.fa");
$B->renderToFile("$tmpdir/catjob.sh");
$catjob = $S->submit("$tmpdir/catjob.sh");
print "Cat job is:\n $catjob";
@catjobline=split /\./, $catjob;


########################################################################################################################
# Remove like vs like and reverse matches
#
$B = $S->getBuilder();

$B->dependency(0, @catjobline[0]); 
#$B->addAction("mv $ENV{PWD}/$tmpdir/blastfinal.tab $ENV{PWD}/$tmpdir/unsorted.blastfinal.tab");
$B->addAction("$toolpath/alphabetize.pl -in $ENV{PWD}/$tmpdir/blastfinal.tab -out $ENV{PWD}/$tmpdir/alphabetized.blastfinal.tab -fasta $ENV{PWD}/$tmpdir/sequences.fa");
$B->addAction("sort -T $sortdir -k1,1 -k2,2 -k5,5nr -t\$\'\\t\' $ENV{PWD}/$tmpdir/alphabetized.blastfinal.tab > $ENV{PWD}/$tmpdir/sorted.alphabetized.blastfinal.tab");
$B->addAction("$toolpath/blastreduce-alpha.pl -blast $ENV{PWD}/$tmpdir/sorted.alphabetized.blastfinal.tab -fasta $ENV{PWD}/$tmpdir/sequences.fa -out $ENV{PWD}/$tmpdir/unsorted.1.out");
$B->addAction("sort -T $sortdir -k5,5nr -t\$\'\\t\' $ENV{PWD}/$tmpdir/unsorted.1.out >$ENV{PWD}/$tmpdir/1.out");
$B->renderToFile("$tmpdir/blastreduce.sh");

$blastreducejob = $S->submit("$tmpdir/blastreduce.sh");
print "Blastreduce job is:\n $blastreducejob";

@blastreducejobline=split /\./, $blastreducejob;


########################################################################################################################
# If multiplexing is on, demultiplex sequences back so all are present
#
$B = $S->getBuilder();

$B->dependency(0, @blastreducejobline[0]); 
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load $efiestmod");
if ($multiplexing eq "on") {
    $B->addAction("mv $ENV{PWD}/$tmpdir/1.out $ENV{PWD}/$tmpdir/mux.out");
    $B->addAction("$toolpath/demux.pl -blastin $ENV{PWD}/$tmpdir/mux.out -blastout $ENV{PWD}/$tmpdir/1.out -cluster $ENV{PWD}/$tmpdir/sequences.fa.clstr");
} else {
    $B->addAction("mv $ENV{PWD}/$tmpdir/1.out $ENV{PWD}/$tmpdir/mux.out");
    $B->addAction("$toolpath/removedups.pl -in $ENV{PWD}/$tmpdir/mux.out -out $ENV{PWD}/$tmpdir/1.out");
}
#$B->addAction("rm $ENV{PWD}/$tmpdir/*blastfinal.tab");
#$B->addAction("rm $ENV{PWD}/$tmpdir/mux.out");
$B->renderToFile("$tmpdir/demux.sh");

$demuxjob = $S->submit("$tmpdir/demux.sh");
print "Demux job is:\n $demuxjob";
@demuxjobline=split /\./, $demuxjob;


########################################################################################################################
# Removed in favor of R, comments kept in case someone ever wants to use the pure perl solution
=pod Start comment
#submit the quartiles scripts, should not run until filterjob is finished
#nothing else depends on this scipt

$B->queue($memqueue);
$B->dependency(0, @demuxjobline[0]); 
$B->addAction("module load oldapps\n" if $oldapps);
$B->addAction("module load $efiestmod");
$B->addAction("$toolpath/quart-align.pl -blastout $ENV{PWD}/$tmpdir/1.out -align $ENV{PWD}/$tmpdir/alignment_length.png");
$B->renderToFile("$tmpdir/quartalign.sh");

$quartalignjob = $S->submit("$tmpdir/quartalign.sh");
print "Quartile Align job is:\n $quartalignjob";


$B->queue($memqueue);
$B->dependency(0, @demuxjobline[0]); 
$B->addAction("#PBS -m e");
$B->addAction("module load oldapps\n" if $oldapps);
$B->addAction("module load $efiestmod");
$B->addAction("$toolpath/quart-perid.pl -blastout $ENV{PWD}/$tmpdir/1.out -pid $ENV{PWD}/$tmpdir/percent_identity.png");
$B->renderToFile("$tmpdir/quartpid.sh");

$quartpidjob = $S->submit("$tmpdir/quartpid.sh");
print "Quartiles Percent Identity job is:\n $quartpidjob";


$B->queue($memqueue);
$B->dependency(0, @demuxjobline[0]); 
$B->addAction("module load oldapps\n" if $oldapps);
$B->addAction("module load $efiestmod");
$B->addAction("$toolpath/simplegraphs.pl -blastout $ENV{PWD}/$tmpdir/1.out -edges $ENV{PWD}/$tmpdir/number_of_edges.png -fasta $ENV{PWD}/$tmpdir/allsequences.fa -lengths $ENV{PWD}/$tmpdir/length_histogram.png -incfrac $incfrac");
$B->renderToFile("$tmpdir/simplegraphs.sh");

$simplegraphjob = $S->submit("$tmpdir/simplegraphs.sh");
print "Simplegraphs job is:\n $simplegraphjob";
=cut end comment


########################################################################################################################
# Create information for R to make graphs and then have R make them
#
$B = $S->getBuilder();

$B->queue($memqueue);
$B->dependency(0, @demuxjobline[0]);
$B->mailEnd();
$B->addAction("module load oldapps") if $oldapps;
$B->addAction("module load ".$ENV{'EFIESTMOD'}."");
$B->addAction("module load $efiestmod");
$B->addAction("$toolpath/R-hdf-graph.py -b $ENV{PWD}/$tmpdir/1.out -f $ENV{PWD}/$tmpdir/rdata.hdf5 -a $ENV{PWD}/$tmpdir/allsequences.fa -i $incfrac");
$B->addAction("Rscript $toolpath/quart-align-hdf5.r $ENV{PWD}/$tmpdir/rdata.hdf5 $ENV{PWD}/$tmpdir/alignment_length.png");
$B->addAction("Rscript $toolpath/quart-perid-hdf5.r $ENV{PWD}/$tmpdir/rdata.hdf5 $ENV{PWD}/$tmpdir/percent_identity.png");
$B->addAction("Rscript $toolpath/hist-hdf5-length.r  $ENV{PWD}/$tmpdir/rdata.hdf5  $ENV{PWD}/$tmpdir/length_histogram.png");
$B->addAction("Rscript $toolpath/hist-hdf5-edges.r $ENV{PWD}/$tmpdir/rdata.hdf5 $ENV{PWD}/$tmpdir/number_of_edges.png");
$B->addAction("touch  $ENV{PWD}/$tmpdir/1.out.completed");
#$B->addAction("rm $ENV{PWD}/$tmpdir/alphabetized.blastfinal.tab $ENV{PWD}/$tmpdir/blastfinal.tab $ENV{PWD}/$tmpdir/sorted.alphabetized.blastfinal.tab $ENV{PWD}/$tmpdir/unsorted.1.out");
$B->renderToFile("$tmpdir/graphs.sh");

$graphjob = $S->submit("$tmpdir/graphs.sh");
print "Graph job is:\n $graphjob";

