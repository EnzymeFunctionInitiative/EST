#!/usr/bin/env perl

use FindBin;
use File::Basename;
use lib "$FindBin::Bin/lib";
use Getopt::Long;
use Biocluster::SchedulerApi;
use Biocluster::Util qw(usesSlurm);
use Biocluster::Config;


$result = GetOptions(
    "seq=s"             => \$seq,
    "tmp|tmpdir=s"      => \$tmpdir,
    "evalue=s"          => \$evalue,
    "multiplexing=s"    => \$multiplexing,
    "lengthdif=f"       => \$lengthdif,
    "sim=f"             => \$sim,
    "np=i"              => \$np,
    "blasthits=i"       => \$blasthits,
    "queue=s"           => \$queue,
    "memqueue=s"        => \$memqueue,
    "nresults=i"        => \$nresults,
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

print "db is: $dbVer\n";
mkdir $tmpdir or die "Could not make directory $tmpdir\n" if not -d $tmpdir;

my $blastDb = "$data_files/combined.fasta";
my $perpass = 1000;
my $incfrac = 0.95;
my $maxhits = 5000;
my $sortdir = '/state/partition1';

unless(defined $evalue){
    print "-evalue not specified, using default of 5\n";
    $evalue="1e-5";
}else{
    if( $evalue =~ /^\d+$/ ) {
        $evalue="1e-$evalue";
    }
}

#defaults and error checking for multiplexing
if($multiplexing eq "on"){
    if(defined $lengthdif){
        unless($lengthdif=~/\d*\.\d+/){
            die "lengthdif must be in a format like 0.9\n";
        }
    }else{
        $lengthdif=1;
    }
    if(defined $sim){
        unless($sim=~/\d*\.\d+/){
            die "sim must be in a format like 0.9\n";
        }   
    }else{
        $sim=1;
    }
}elsif(!(defined $multiplexing)){
    $multiplexing="on";
    if(defined $lengthdif){
        unless($lengthdif=~/\d*\.\d+/){
            die "lengthdif must be in a format like 0.9\n";
        }
    }else{
        $lengthdif=1;
    }
    if(defined $sim){
        unless($sim=~/\d*\.\d+/){
            die "sim must be in a format like 0.9\n";
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



open(QUERY, ">$ENV{PWD}/$tmpdir/query.fa") or die "Cannot write out Query File to \n";
print QUERY ">000000\n$seq\n";
close QUERY;

print "\nBlast for similar sequences and sort based off bitscore\n";

my $B = $S->getBuilder();

$B = $S->getBuilder();
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
$B->addAction("cd $ENV{PWD}/$tmpdir");
$B->addAction("which perl");
$B->addAction("blastall -p blastp -i $ENV{PWD}/$tmpdir/query.fa -d $blastDb -m 8 -e $evalue -b $nresults -o $ENV{PWD}/$tmpdir/initblast.out");
$B->addAction("cat $ENV{PWD}/$tmpdir/initblast.out |grep -v '#'|cut -f 1,2,3,4,12 |sort -k5,5nr >$ENV{PWD}/$tmpdir/blastfinal.tab");
#$B->addAction("rm $ENV{PWD}/$tmpdir/initblast.out");
#$B->addAction("$efiEstTools/getannotations.pl $userdat -out ".$ENV{PWD}."/$tmpdir/struct.out -fasta ".$ENV{PWD}."/$tmpdir/allsequences.fa");
$B->renderToFile("$tmpdir/blasthits_initial_blast.sh");

$initblastjob= $S->submit("$tmpdir/blasthits_initial_blast.sh");
print "initial blast job is:\n $initblastjob";
@initblastjobline=split /\./, $initblastjob;



$B = $S->getBuilder();
$B->dependency(0, @initblastjobline[0]); 
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
$B->addAction("cd $ENV{PWD}/$tmpdir");
$B->addAction("which perl");
$B->addAction("$efiEstTools/blasthits-getmatches.pl -blastfile $ENV{PWD}/$tmpdir/blastfinal.tab -accessions $ENV{PWD}/$tmpdir/accessions.txt -max $nresults");
$B->renderToFile("$tmpdir/blasthits_getmatches.sh");

$getmatchesjob= $S->submit("$tmpdir/blasthits_getmatches.sh");
print "getmatches job is:\n $getmatchesjob";
@getmatchesjobline=split /\./, $getmatchesjob;




$B = $S->getBuilder();
$B->dependency(0, @getmatchesjobline[0]); 
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
$B->addAction("cd $ENV{PWD}/$tmpdir");
$B->addAction("which perl");
$B->addAction("blasthits-createfasta.pl -fasta allsequences.fa -accessions accessions.txt");
$B->renderToFile("$tmpdir/blasthits_createfasta.sh");

$createfastajob= $S->submit("$tmpdir/blasthits_createfasta.sh");
print "createfasta job is:\n $createfastajob";
@createfastajobline=split /\./, $createfastajob;



$B = $S->getBuilder();
$B->dependency(0, @createfastajobline[0]); 
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
$B->addAction("cd $ENV{PWD}/$tmpdir");
$B->addAction("which perl");
$B->addAction("getannotations.pl -out ".$ENV{PWD}."/$tmpdir/struct.out -fasta ".$ENV{PWD}."/$tmpdir/allsequences.fa -config=$configFile");
$B->renderToFile("$tmpdir/blasthits_getannotations.sh");

$annotationjob= $S->submit("$tmpdir/blasthits_getannotations.sh");
print "annotation job is:\n $annotationjob";
@annotationjobline=split /\./, $annotationjob;



#if multiplexing is on, run an initial cdhit to get a reduced set of "more" unique sequences
#if not, just copy allsequences.fa to sequences.fa so next part of program is set up right
$B = $S->getBuilder();
$B->dependency(0, @createfastajobline[0]); 
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
#  $B->addAction("module load blast");
$B->addAction("cd $ENV{PWD}/$tmpdir");
if($multiplexing eq "on"){
    $B->addAction("cd-hit -c $sim -s $lengthdif -i $ENV{PWD}/$tmpdir/allsequences.fa -o $ENV{PWD}/$tmpdir/sequences.fa");
}else{
    $B->addAction("cp $ENV{PWD}/$tmpdir/allsequences.fa $ENV{PWD}/$tmpdir/sequences.fa");
}
$B->renderToFile("$tmpdir/blasthits_multiplex.sh");

$muxjob= $S->submit("$tmpdir/blasthits_multiplex.sh");
print "multiplex job is:\n $muxjob";
@muxjobline=split /\./, $muxjob;



#break sequenes.fa into $np parts for blast
$B = $S->getBuilder();

$B->dependency(0, @muxjobline[0]); 
$B->addAction("module load $efiEstMod");
$B->addAction("$efiEstTools/splitfasta.pl -parts $np -tmp ".$ENV{PWD}."/$tmpdir -source $ENV{PWD}/$tmpdir/sequences.fa");
$B->renderToFile("$tmpdir/blasthits_fracfile.sh");

$fracfilejob= $S->submit("$tmpdir/blasthits_fracfile.sh");
print "fracfile job is: $fracfilejob";
@fracfilejobline=split /\./, $fracfilejob;



#make the blast database and put it into the temp directory
$B = $S->getBuilder();
$B->dependency(0, @muxjobline[0]);
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
$B->addAction("cd $ENV{PWD}/$tmpdir");
$B->addAction("formatdb -i sequences.fa -n database -p T -o T ");
$B->renderToFile("$tmpdir/blasthits_createdb.sh");

$createdbjob= $S->submit("$tmpdir/blasthits_createdb.sh");
print "createdb job is:\n $createdbjob";
@createdbjobline=split /\./, $createdbjob;



#generate $np blast scripts for files from fracfile step
$B = $S->getBuilder();
$B->jobArray("1-$np");
$B->dependency(0, @createdbjobline[0] . ":" . @fracfilejobline[0]);
$B->addAction("module load $efiEstMod");
$B->addAction("export BLASTDB=$ENV{PWD}/$tmpdir");
#$B->addAction("module load blast+");
#$B->addAction("blastp -query  $ENV{PWD}/$tmpdir/fracfile-\${PBS_ARRAYID}.fa  -num_threads 2 -db database -gapopen 11 -gapextend 1 -comp_based_stats 2 -use_sw_tback -outfmt \"6 qseqid sseqid bitscore evalue qlen slen length qstart qend sstart send pident nident\" -num_descriptions 5000 -num_alignments 5000 -out $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.tab -evalue $evalue");
$B->addAction("module load $efiDbMod");
$B->addAction("blastall -p blastp -i $ENV{PWD}/$tmpdir/fracfile-\${PBS_ARRAYID}.fa -d $ENV{PWD}/$tmpdir/database -m 8 -e $evalue -b $blasthits -o $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.tab");
$B->renderToFile("$tmpdir/blasthits_blast-qsub.sh");


$blastjob= $S->submit("$tmpdir/blasthits_blast-qsub.sh");
print "blast job is:\n $blastjob";
@blastjobline=split /\./, $blastjob;




#join all the blast outputs back together
$B = $S->getBuilder();
$B->dependency(1, @blastjobline[0]); 
$B->addAction("cat $ENV{PWD}/$tmpdir/blastout-*.tab |grep -v '#'|cut -f 1,2,3,4,12 >$ENV{PWD}/$tmpdir/blastfinal.tab");
$B->addAction("rm  $ENV{PWD}/$tmpdir/blastout-*.tab");
$B->addAction("rm  $ENV{PWD}/$tmpdir/fracfile-*.fa");
$B->renderToFile("$tmpdir/blasthits_catjob.sh");

$catjob= $S->submit("$tmpdir/blasthits_catjob.sh");
print "Cat job is:\n $catjob";
@catjobline=split /\./, $catjob;




#Remove like vs like and reverse matches
$B = $S->getBuilder();
$B->queue($memqueue);
$B->dependency(0, @catjobline[0]); 
$B->addAction("module load $efiEstMod");
#$B->addAction("mv $ENV{PWD}/$tmpdir/blastfinal.tab $ENV{PWD}/$tmpdir/unsorted.blastfinal.tab");
$B->addAction("$efiEstTools/alphabetize.pl -in $ENV{PWD}/$tmpdir/blastfinal.tab -out $ENV{PWD}/$tmpdir/alphabetized.blastfinal.tab -fasta $ENV{PWD}/$tmpdir/sequences.fa");
$B->addAction("sort -T $sortdir -k1,1 -k2,2 -k5,5nr -t\$\'\\t\' $ENV{PWD}/$tmpdir/alphabetized.blastfinal.tab > $ENV{PWD}/$tmpdir/sorted.alphabetized.blastfinal.tab");
$B->addAction("$efiEstTools/blastreduce-alpha.pl -blast $ENV{PWD}/$tmpdir/sorted.alphabetized.blastfinal.tab -fasta $ENV{PWD}/$tmpdir/sequences.fa -out $ENV{PWD}/$tmpdir/unsorted.1.out");
$B->addAction("sort -T $sortdir -k5,5nr -t\$\'\\t\' $ENV{PWD}/$tmpdir/unsorted.1.out >$ENV{PWD}/$tmpdir/1.out");
$B->renderToFile("$tmpdir/blasthits_blastreduce.sh");

$blastreducejob= $S->submit("$tmpdir/blasthits_blastreduce.sh");
print "Blastreduce job is:\n $blastreducejob";
@blastreducejobline=split /\./, $blastreducejob;



#if multiplexing is on, demultiplex sequences back so all are present

$B = $S->getBuilder();
$B->queue($memqueue);
$B->dependency(0, @blastreducejobline[0]); 
$B->addAction("module load $efiEstMod");
if($multiplexing eq "on"){
    $B->addAction("mv $ENV{PWD}/$tmpdir/1.out $ENV{PWD}/$tmpdir/mux.out");
    $B->addAction("$efiEstTools/demux.pl -blastin $ENV{PWD}/$tmpdir/mux.out -blastout $ENV{PWD}/$tmpdir/1.out -cluster $ENV{PWD}/$tmpdir/sequences.fa.clstr");
}else{
    $B->addAction("mv $ENV{PWD}/$tmpdir/1.out $ENV{PWD}/$tmpdir/mux.out");
    $B->addAction("$efiEstTools/removedups.pl -in $ENV{PWD}/$tmpdir/mux.out -out $ENV{PWD}/$tmpdir/1.out");
}
#$B->addAction("rm $ENV{PWD}/$tmpdir/*blastfinal.tab");
#$B->addAction("rm $ENV{PWD}/$tmpdir/mux.out");
$B->renderToFile("$tmpdir/blasthits_demux.sh");

$demuxjob= $S->submit("$tmpdir/blasthits_demux.sh");
print "Demux job is:\n $demuxjob";
@demuxjobline=split /\./, $demuxjob;




#create information for R to make graphs and then have R make them
$B = $S->getBuilder();
$B->queue($memqueue);
$B->dependency(0, @demuxjobline[0]); 
$B->mailEnd();
$B->addAction("module load $efiEstMod");
$B->addAction("module load $efiDbMod");
#$B->addAction("module load R/3.1.0");
$B->addAction("mkdir $ENV{PWD}/$tmpdir/rdata");
$B->addAction("$efiEstTools/Rgraphs.pl -blastout $ENV{PWD}/$tmpdir/1.out -rdata  $ENV{PWD}/$tmpdir/rdata -edges  $ENV{PWD}/$tmpdir/edge.tab -fasta  $ENV{PWD}/$tmpdir/allsequences.fa -length  $ENV{PWD}/$tmpdir/length.tab -incfrac $incfrac");
$B->addAction("FIRST=`ls $ENV{PWD}/$tmpdir/rdata/perid*| head -1`");
$B->addAction("FIRST=`head -1 \$FIRST`");
$B->addAction("LAST=`ls $ENV{PWD}/$tmpdir/rdata/perid*| tail -1`");
$B->addAction("LAST=`head -1 \$LAST`");
$B->addAction("MAXALIGN=`head -1 $ENV{PWD}/$tmpdir/rdata/maxyal`");
$B->addAction("Rscript $efiEstTools/quart-align.r $ENV{PWD}/$tmpdir/rdata $ENV{PWD}/$tmpdir/alignment_length.png \$FIRST \$LAST \$MAXALIGN");
$B->addAction("Rscript $efiEstTools/quart-perid.r $ENV{PWD}/$tmpdir/rdata $ENV{PWD}/$tmpdir/percent_identity.png \$FIRST \$LAST");
$B->addAction("Rscript $efiEstTools/hist-length.r  $ENV{PWD}/$tmpdir/length.tab  $ENV{PWD}/$tmpdir/length_histogram.png");
$B->addAction("Rscript $efiEstTools/hist-edges.r $ENV{PWD}/$tmpdir/edge.tab $ENV{PWD}/$tmpdir/number_of_edges.png");
$B->addAction("touch  $ENV{PWD}/$tmpdir/1.out.completed");
#$B->addAction("rm $ENV{PWD}/$tmpdir/alphabetized.blastfinal.tab $ENV{PWD}/$tmpdir/blastfinal.tab $ENV{PWD}/$tmpdir/sorted.alphabetized.blastfinal.tab $ENV{PWD}/$tmpdir/unsorted.1.out");
$B->renderToFile("$tmpdir/blasthits_graphs.sh");

$graphjob= $S->submit("$tmpdir/blasthits_graphs.sh");
print "Graph job is:\n $graphjob";



