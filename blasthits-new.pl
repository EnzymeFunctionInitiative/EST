#!/usr/bin/env perl

use Getopt::Long;
use DBD::SQLite;
use DBD::mysql;
use File::Slurp;

$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
eval $configfile;

$result=GetOptions (	"seq=s"	=> \$seq,
			"tmpdir=s"	=> \$tmpdir,
			"evalue=s"	=> \$evalue,
			"multiplexing=s"=> \$multiplexing,
			"lengthdif=f"	=> \$lengthdif,
			"sim=f"		=> \$sim,
			"np=i"		=> \$np,
			"blasthits=i"	=> \$blasthits,
			"queue=s"	=> \$queue,
			"memqueue=s"	=> \$memqueue,
			"nresults=i"    => \$nresults,

		    );

$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
eval $configfile;

$efiestmod=$ENV{'EFIDBMOD'};
$toolpath=$ENV{'EFIEST'};

print "db is: $db\n";
mkdir $tmpdir or die "Could not make directory $tmpdir\n";

#$db="$ENV{EFIEST}/data_files/combined.fasta";
#$sqlite="$ENV{EFIEST}/data_files/uniprot_combined.db";
$db="$data_files/combined.fasta";
$perpass=1000;
$incfrac=0.95;
$maxhits=5000;
$sortdir='/state/partition1';


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

open(QUERY, ">$ENV{PWD}/$tmpdir/query.fa") or die "Cannot write out Query File to \n";
print QUERY ">000000\n$seq\n";
close QUERY;

print "\nBlast for similar sequences and sort based off bitscore\n";

open(QSUB,">$tmpdir/blasthits_initial_blast.sh") or die "could not create blast submission script $tmpdir/blasthits_initial_blast.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "module load $efiestmod\n";
print QSUB "cd $ENV{PWD}/$tmpdir\n";
print QSUB "which perl\n";
print QSUB "blastall -p blastp -i $ENV{PWD}/$tmpdir/query.fa -d $db -m 8 -e $evalue -b $nresults -o $ENV{PWD}/$tmpdir/initblast.out\n";
print QSUB "cat $ENV{PWD}/$tmpdir/initblast.out |grep -v '#'|cut -f 1,2,3,4,12 |sort -k5,5nr >$ENV{PWD}/$tmpdir/blastfinal.tab\n";
#print QSUB "rm $ENV{PWD}/$tmpdir/initblast.out";
#print QSUB "$toolpath/getannotations.pl $userdat -out ".$ENV{PWD}."/$tmpdir/struct.out -fasta ".$ENV{PWD}."/$tmpdir/allsequences.fa\n";
close QSUB;

$initblastjob=`qsub $tmpdir/blasthits_initial_blast.sh`;
print "initial blast job is:\n $initblastjob";
@initblastjobline=split /\./, $initblastjob;

open(QSUB,">$tmpdir/blasthits_getmatches.sh") or die "could not create blast submission script $tmpdir/blasthits_getmatches.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@initblastjobline[0]\n"; 
print QSUB "module load $efiestmod\n";
print QSUB "cd $ENV{PWD}/$tmpdir\n";
print QSUB "which perl\n";
print QSUB "$toolpath/blasthits-getmatches.pl -blastfile $ENV{PWD}/$tmpdir/blastfinal.tab -accessions $ENV{PWD}/$tmpdir/accessions.txt -max $nresults\n";
close QSUB;

$getmatchesjob=`qsub $tmpdir/blasthits_getmatches.sh`;
print "getmatches job is:\n $getmatchesjob";
@getmatchesjobline=split /\./, $getmatchesjob;


open(QSUB,">$tmpdir/blasthits_createfasta.sh") or die "could not create blast submission script $tmpdir/blasthits_createfasta\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@getmatchesjobline[0]\n"; 
print QSUB "module load $efiestmod\n";
print QSUB "cd $ENV{PWD}/$tmpdir\n";
print QSUB "which perl\n";
print QSUB "blasthits-createfasta.pl -fasta allsequences.fa -accessions accessions.txt\n";
close QSUB;

$createfastajob=`qsub $tmpdir/blasthits_createfasta.sh`;
print "createfasta job is:\n $createfastajob";
@createfastajobline=split /\./, $createfastajob;

open(QSUB,">$tmpdir/blasthits_getannotations.sh") or die "could not create blast submission script $tmpdir/blasthits_createannotations\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@createfastajobline[0]\n"; 
print QSUB "module load $efiestmod\n";
print QSUB "cd $ENV{PWD}/$tmpdir\n";
print QSUB "which perl\n";
print QSUB "getannotations.pl -out ".$ENV{PWD}."/$tmpdir/struct.out -fasta ".$ENV{PWD}."/$tmpdir/allsequences.fa\n";
close QSUB;

$annotationjob=`qsub $tmpdir/blasthits_getannotations.sh`;
print "annotation job is:\n $annotationjob";
@annotationjobline=split /\./, $annotationjob;

#if multiplexing is on, run an initial cdhit to get a reduced set of "more" unique sequences
#if not, just copy allsequences.fa to sequences.fa so next part of program is set up right
open(QSUB,">$tmpdir/blasthits_multiplex.sh") or die "could not create blast submission script $tmpdir/multiplex.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@createfastajobline[0]\n"; 
print QSUB "module load $efiestmod\n";
#  print QSUB "module load blast\n";
print QSUB "cd $ENV{PWD}/$tmpdir\n";
if($multiplexing eq "on"){
  print QSUB "cd-hit -c $sim -s $lengthdif -i $ENV{PWD}/$tmpdir/allsequences.fa -o $ENV{PWD}/$tmpdir/sequences.fa\n";
}else{
  print QSUB "cp $ENV{PWD}/$tmpdir/allsequences.fa $ENV{PWD}/$tmpdir/sequences.fa\n";
}
close QSUB;

$muxjob=`qsub $tmpdir/blasthits_multiplex.sh`;
print "multiplex job is:\n $muxjob";
@muxjobline=split /\./, $muxjob;

#break sequenes.fa into $np parts for blast
open(QSUB,">$tmpdir/blasthits_fracfile.sh") or die "could not create blast submission script $tmpdir/fracfile.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@muxjobline[0]\n"; 
print QSUB "$toolpath/splitfasta.pl -parts $np -tmp ".$ENV{PWD}."/$tmpdir -source $ENV{PWD}/$tmpdir/sequences.fa\n";
close QSUB;

$fracfilejob=`qsub $tmpdir/blasthits_fracfile.sh`;
print "fracfile job is:\n $fracfilejob";
@fracfilejobline=split /\./, $fracfilejob;

#make the blast database and put it into the temp directory
open(QSUB,">$tmpdir/blasthits_createdb.sh") or die "could not create blast submission script $tmpdir/createdb.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@muxjobline[0]\n";
print QSUB "module load $efiestmod\n";
print QSUB "cd $ENV{PWD}/$tmpdir\n";
print QSUB "formatdb -i sequences.fa -n database -p T -o T \n";
close QSUB;

$createdbjob=`qsub $tmpdir/blasthits_createdb.sh`;
print "createdb job is:\n $createdbjob";
@createdbjobline=split /\./, $createdbjob;

#generate $np blast scripts for files from fracfile step
open(QSUB,">$tmpdir/blasthits_blast-qsub.sh") or die "could not create blast submission script $tmpdir/blast-qsub-$i.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -t 1-$np\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@createdbjobline[0]:@fracfilejobline[0]\n";
print QSUB "export BLASTDB=$ENV{PWD}/$tmpdir\n";
#print QSUB "module load blast+\n";
#print QSUB "blastp -query  $ENV{PWD}/$tmpdir/fracfile-\${PBS_ARRAYID}.fa  -num_threads 2 -db database -gapopen 11 -gapextend 1 -comp_based_stats 2 -use_sw_tback -outfmt \"6 qseqid sseqid bitscore evalue qlen slen length qstart qend sstart send pident nident\" -num_descriptions 5000 -num_alignments 5000 -out $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.tab -evalue $evalue\n";
print QSUB "module load $efiestmod\n";
print QSUB "blastall -p blastp -i $ENV{PWD}/$tmpdir/fracfile-\${PBS_ARRAYID}.fa -d $ENV{PWD}/$tmpdir/database -m 8 -e $evalue -b $blasthits -o $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.tab\n";
close QSUB;


$blastjob=`qsub $tmpdir/blasthits_blast-qsub.sh`;
print "blast job is:\n $blastjob";
@blastjobline=split /\./, $blastjob;


#join all the blast outputs back together
open(QSUB,">$tmpdir/blasthits_catjob.sh") or die "could not create blast submission script $tmpdir/catjob.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterokarray:@blastjobline[0]\n"; 
print QSUB "cat $ENV{PWD}/$tmpdir/blastout-*.tab |grep -v '#'|cut -f 1,2,3,4,12 >$ENV{PWD}/$tmpdir/blastfinal.tab\n";
print QSUB "rm  $ENV{PWD}/$tmpdir/blastout-*.tab\n";
print QSUB "rm  $ENV{PWD}/$tmpdir/fracfile-*.fa\n";
close QSUB;

$catjob=`qsub $tmpdir/blasthits_catjob.sh`;
print "Cat job is:\n $catjob";
@catjobline=split /\./, $catjob;


#Remove like vs like and reverse matches
open(QSUB,">$tmpdir/blasthits_blastreduce.sh") or die "could not create blast submission script $tmpdir/blastreduce.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $memqueue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@catjobline[0]\n"; 
#print QSUB "mv $ENV{PWD}/$tmpdir/blastfinal.tab $ENV{PWD}/$tmpdir/unsorted.blastfinal.tab\n";
print QSUB "$toolpath/alphabetize.pl -in $ENV{PWD}/$tmpdir/blastfinal.tab -out $ENV{PWD}/$tmpdir/alphabetized.blastfinal.tab -fasta $ENV{PWD}/$tmpdir/sequences.fa\n";
print QSUB "sort -T $sortdir -k1,1 -k2,2 -k5,5nr -t\$\'\\t\' $ENV{PWD}/$tmpdir/alphabetized.blastfinal.tab > $ENV{PWD}/$tmpdir/sorted.alphabetized.blastfinal.tab\n";
print QSUB "$toolpath/blastreduce-alpha.pl -blast $ENV{PWD}/$tmpdir/sorted.alphabetized.blastfinal.tab -fasta $ENV{PWD}/$tmpdir/sequences.fa -out $ENV{PWD}/$tmpdir/unsorted.1.out\n";
print QSUB "sort -T $sortdir -k5,5nr -t\$\'\\t\' $ENV{PWD}/$tmpdir/unsorted.1.out >$ENV{PWD}/$tmpdir/1.out\n";
close QSUB;

$blastreducejob=`qsub $tmpdir/blasthits_blastreduce.sh`;
print "Blastreduce job is:\n $blastreducejob";
@blastreducejobline=split /\./, $blastreducejob;

#if multiplexing is on, demultiplex sequences back so all are present

open(QSUB,">$tmpdir/blasthits_demux.sh") or die "could not create blast submission script $tmpdir/demux.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $memqueue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@blastreducejobline[0]\n"; 
if($multiplexing eq "on"){
  print QSUB "mv $ENV{PWD}/$tmpdir/1.out $ENV{PWD}/$tmpdir/mux.out\n";
  print QSUB "$toolpath/demux.pl -blastin $ENV{PWD}/$tmpdir/mux.out -blastout $ENV{PWD}/$tmpdir/1.out -cluster $ENV{PWD}/$tmpdir/sequences.fa.clstr\n";
}else{
  print QSUB "mv $ENV{PWD}/$tmpdir/1.out $ENV{PWD}/$tmpdir/mux.out\n";
  print QSUB "$toolpath/removedups.pl -in $ENV{PWD}/$tmpdir/mux.out -out $ENV{PWD}/$tmpdir/1.out\n";
}
#print QSUB "rm $ENV{PWD}/$tmpdir/*blastfinal.tab\n";
#print QSUB "rm $ENV{PWD}/$tmpdir/mux.out\n";
close QSUB;

$demuxjob=`qsub $tmpdir/blasthits_demux.sh`;
print "Demux job is:\n $demuxjob";
@demuxjobline=split /\./, $demuxjob;


#create information for R to make graphs and then have R make them
open(QSUB,">$tmpdir/blasthits_graphs.sh") or die "could not create blast submission script $tmpdir/graphs.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $memqueue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@demuxjobline[0]\n"; 
print QSUB "#PBS -m e\n";
print QSUB "module load $efiestmod\n";
#print QSUB "module load R/3.1.0\n";
print QSUB "mkdir $ENV{PWD}/$tmpdir/rdata\n";
print QSUB "$toolpath/Rgraphs.pl -blastout $ENV{PWD}/$tmpdir/1.out -rdata  $ENV{PWD}/$tmpdir/rdata -edges  $ENV{PWD}/$tmpdir/edge.tab -fasta  $ENV{PWD}/$tmpdir/allsequences.fa -length  $ENV{PWD}/$tmpdir/length.tab -incfrac $incfrac\n";
print QSUB "FIRST=`ls $ENV{PWD}/$tmpdir/rdata/perid*| head -1`\n";
print QSUB "FIRST=`head -1 \$FIRST`\n";
print QSUB "LAST=`ls $ENV{PWD}/$tmpdir/rdata/perid*| tail -1`\n";
print QSUB "LAST=`head -1 \$LAST`\n";
print QSUB "MAXALIGN=`head -1 $ENV{PWD}/$tmpdir/rdata/maxyal`\n";
print QSUB "Rscript $toolpath/quart-align.r $ENV{PWD}/$tmpdir/rdata $ENV{PWD}/$tmpdir/alignment_length.png \$FIRST \$LAST \$MAXALIGN\n";
print QSUB "Rscript $toolpath/quart-perid.r $ENV{PWD}/$tmpdir/rdata $ENV{PWD}/$tmpdir/percent_identity.png \$FIRST \$LAST\n";
print QSUB "Rscript $toolpath/hist-length.r  $ENV{PWD}/$tmpdir/length.tab  $ENV{PWD}/$tmpdir/length_histogram.png\n";
print QSUB "Rscript $toolpath/hist-edges.r $ENV{PWD}/$tmpdir/edge.tab $ENV{PWD}/$tmpdir/number_of_edges.png\n";
print QSUB "touch  $ENV{PWD}/$tmpdir/1.out.completed\n";
#print QSUB "rm $ENV{PWD}/$tmpdir/alphabetized.blastfinal.tab $ENV{PWD}/$tmpdir/blastfinal.tab $ENV{PWD}/$tmpdir/sorted.alphabetized.blastfinal.tab $ENV{PWD}/$tmpdir/unsorted.1.out\n";
close QSUB;

$graphjob=`qsub $tmpdir/blasthits_graphs.sh`;
print "Graph job is:\n $graphjob";
