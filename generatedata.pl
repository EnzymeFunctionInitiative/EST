#!/usr/bin/env perl
#version 0.1 the make it work version
#version 0.2 combined initial db creation, population, and pythoscape scripts up to inserting edges
#version 0.2.1 added expression line to select type of search done in plugin1 of initial_import.py, added capacity to include sequence length
#version 0.3.0 added ability to input edges through Input_edges.pl
#version 0.5.0 added ability to create quartiles, bandpass sequences based off length, and fixed a problem in fracfile when np was around the number of sequences in a file.
#version 0.6.0 removed ability to create quartiles, removed use of mysql database, the first pure perl version
#version 0.7.0 major rewrite, removes need for mysql database, remove all of original pythoscape code
#version 0.8.0 split pipeline into two parts, added code to create quartiles
#version 0.8.1 Added ability to run program off pfam or Interpro numbers
#version 0.8.3 Added ability to run program off Tax IDs
#version 0.8.5 Added $maxhits (set to 50,000 for now) so we can get up to 50k results from a single blast search
#version 0.9.0 Updated from the getsequence.pl progrma to sqlite-getsequence (new file uses sqlite db of match_coplete and also allows for ssf and gene3d numbers to generate networks.
#version 0.9.1 Added abiltity to use non database informations through fasta files and struct.out files
#version 0.9.1 Filterblast section renamed blastreduce to avoid confusion with filtering from analyze data step
#version 0.9.1 blast-X.fa.tab and fracfile-X.fa files are now removed after blast results are concatenated together
#version 0.9.1 blastfinal.tab is now removed after the 1.out file is created int he blastreduce step
#version 0.9.2 no changes to this file
#version 0.9.3 added options and features for multiplexing to shorten number of blast queries
#version 0.9.3 removed code (via comment) for creating perl based graphs
#version 0.9.3 added code for creating graphs via R
#version 0.9.3 added sort code to blastreduce step so that best edge (via bitscore) is always chosen
#version 0.9.4 changed name of get sequence script from sqlite-getsequence.pl to getsequence.pl
#version 0.9.4 moved from specific fracfile.pl to general splitsequence.pl for splitting up blast files
#version 0.9.4 started removing *blastfinal.tab files in demux step
#version 0.9.5 added code to hold database version, stores in database_version in the SDF
#version 0.9.6 modified graph creation to use hdf5 instead of plain files
#version 0.9.6 hdf5 creating program is in python due to poor hdf5 perl libraries
#version 0.9.6 added blast option to generatedata.pl to choose between blast, blast+, and diamond (default is blast)

#this program creates bash scripts and submits them on clusters with torque schedulers, overview of steps below
#Step 1 fetch sequences and get annotations
  #initial_import.sh		generates initial_import script that contains getsequence.pl and getannotation.pl or just getseqtaxid.pl if input was from taxid
    #getsequence.pl		grabs sequence data for input (other than taxid) submits jobs that do the following makes allsequences.fa
    #getannotations.pl		grabs annotations for input (other than taxid) creates struct.out file makes struct.out
    #getseqtaxid.pl		get sequence data and annotations based on taxid makes both struct.out and allsequences.fa
#Step 2 reduce number of searches
  #multiplex.sh			performs a cdhit on the input 
    #cdhit is an open source tool that groups sequences based on similarity and length, unique sequences in sequences.fa
    #cdhit also creates sequences.fa.clustr for demultiplexing sequences later
    #if multiplexing is turned off, then this just copies allsequences.fa to sequences.fa
#Step 3 break up the sequences so we can use more processors
  #fracfile.sh			breaks sequences.fa into -np parts for basting
    #fracsequence.pl		breaks fasta sequence into np parts for blasting
#Step 4 Make fasta database
  #createdb.sh			makes fasta database out of sequences.fa
    #formatdb			blast program to format sequences.fa into database
#Step 5 Blast
  #blast-qsub.sh		job array of np elements that blasts each fraction of sequences.fa against database of sequences.fa
    #blastall			blast program that does the compares
#Step 6 Combine blasts back together
  #catjob.sh			concationates blast output files together into blastfinal.tab
    #cat			linux program to read a file out
#Step 7 Remove extra edge information
  #blastreduce.sh		removes like and reverse matches of blastfinal.tab and saves as 1.out
    #sort			sort blast results so that the best blast results (via bitscore) are first
    #blastreduce.pl		actually does the heavy lifting
    #rm 			removes blastfinal.tab
#Step 8 Add back in edges removed by step 2
  #demux.sh			adds blast results back in for sequences that were removed in multiplex step
    #mv				moves current 1.out to mux.out
    #demux.pl			reads in mux.out and sequences.fa.clustr and generates new 1.out
#Step 9 Make graphs 
  #graphs.sh			creates percent identity and alignment length quartiles as well as sequence length and edge value bar graphs
    #mkidr			makes directory for R quartile information (rdata)
    #Rgraphs.pl			reads through 1.out and saves tab delimited files for use in bar graphs (length.tab edge.tab)
    #Rgraphs.pl			saves quartile data into rdata
    #paste			makes tab delimited files like R needs from rdata/align* and rdata/perid* and makes align.tab and perid.tab
    #quart-align.r		Makes alignment length quartile graph (r_quartile_align.png) from tab file
    #quart-perid.r		Makes percent identity quartile graph (r_quartile_perid.png) from tab file
    #hist-length.r		Makes sequence length bar graph (r_hist_length.png) from tab file
    #hist-edges.r		Makes edges bar graph (r_hist_edges.png) from tab file


#perl module for loading command line options
use Getopt::Long;
use POSIX qw(ceil);


$result=GetOptions ("np=i"		=> \$np,
		    "queue=s"		=> \$queue,
		    "tmp=s"		=> \$tmpdir,
		    "evalue=s"		=> \$evalue,
		    "incfrac=f"		=> \$incfrac,
		    "ipro=s"		=> \$ipro,
		    "pfam=s"		=> \$pfam,
		    "taxid=s"		=> \$taxid,
		    "gene3d=s"		=> \$gene3d,
		    "ssf=s"		=> \$ssf,
		    "blasthits=i"	=> \$blasthits,
		    "memqueue=s"	=> \$memqueue,
		    "maxsequence=s"	=> \$maxsequence,
		    "userdat=s"		=> \$userdat,
		    "userfasta=s"	=> \$userfasta,
		    "lengthdif=f"	=> \$lengthdif,
		    "sim=f"		=> \$sim,
		    "multiplex=s"	=> \$multiplexing,
		    "domain=s"		=> \$domain,
		    "fraction=i"	=> \$fraction,
		    "blast=s"		=> \$blast);

$toolpath=$ENV{'EFIEST'};
$efiestmod=$ENV{'EFIDBMOD'};
$efidbmod=$efiestmod;
$sortdir='/state/partition1';

#defaults and error checking for choosing of blast program

if(defined $blast){
  unless($blast eq "blast" or $blast eq "blast+" or $blast eq "diamond" or $blast eq 'diamondsensitive'){
    die "blast program value of $blast is not valid, must be blast, blast+, diamondsensitive, or diamond\n";
  }
}else{
  $blast="blast";
}

print "Blast is $blast\n";

#defaults and error checking for splitting sequences into domains

if(defined $domain){
  unless($domain eq "off" or $domain eq "on"){
    die "domain value of $domain is not valid, must be either on or off\n";
  }
}else{
  $domain="off";
}

#defaults for fraction of sequences to fetch

if(defined $fraction){
  unless($fraction=~/^\d+$/ and $fraction >0){
    die "if fraction is defined, it must be greater than zero\n";
  }
}else{
  $fraction=1;
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
}elsif($multiplexing eq "off"){
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

#max number of hits for an individual sequence, normally set ot max value
unless(defined $blasthits){
  $blasthits=1000000;  
}

#at least one of tehse inputs are required to get sequences for the program
unless(defined $userfasta or defined $ipro or defined $pfam or defined $taxid or defined $ssf or defined $gene3d){
  die "You must spedify the -fasta, -ipro, -taxid, or -pfam variables\n";
}

#you also have to specify the number of processors for blast
unless(defined $np){
  die "You must spedify the -np variable\n";
}
if($blast=~/diamond/){
  $np=ceil($np/24);
}

#default queues
unless(defined $queue){
  print "-queue not specified, using default\n";
  $queue="efi";
}
unless(defined $memqueue){
  print "-memqueue not specifiied, using default\n";
  $memqueue="efi-mem";
}

#working directory must be defined
unless(defined $tmpdir){
  die "You must spedify the -tmp variable\n";
}

#default e value must also be set for blast, default set if not specified
unless(defined $evalue){
  print "-evalue not specified, using default of 5\n";
  $evalue="1e-5";
}else{
  if( $evalue =~ /^\d+$/ ) { 
    $evalue="1e-$evalue";
  }
}


#set input families to zero if they are not specified
unless(defined $pfam){
  $pfam=0;
}
unless(defined $ipro){
  $ipro=0;
}

unless(defined $taxid){
  $taxid=0;
}

unless(defined $gene3d){
  $gene3d=0;
}

unless(defined $ssf){
  $ssf=0;
}

#default values for bandpass filter, 0,0 disables it, which is the default
unless(defined $maxlen){
  $maxlen=0;
}
unless(defined $minlen){
  $minlen=0;
}

#fraction of sequences to include in graphs, reduces effects of outliers
unless(defined $incfrac){
  print "-incfrac not specified, using default of 0.99\n";
  $incfrac=0.99;
}

#maximum number of sequences to process, 0 disables it
unless(defined $maxsequence){
  $maxsequence=0;
}




if(defined $userfasta and -e $userfasta){
#error checking for user supplied dat and fa files
  unless(($userfasta=~/^\// or $userfasta=~/^~/) and defined $userfasta){
    $userfasta=$ENV{PWD}."/$userfasta";
  }
  $userfasta="-userfasta $userfasta"
}elsif(defined $userfasta){
  die "$userfasta does not exist\n";
}else{
  $userfasta="";
  #die "this should never happen, may be userfasta flagged but not given\n";
}




if(defined $userdat and -e $userdat){
  unless(($userdat=~/^\// or $userdat=~/^~/) and defined $userdat){
    $userdat=$ENV{PWD}."/$userdat";
  }
  $userdat="-userdat $userdat";
}elsif(defined $userdat){
  die "$userdat does not exist\n";
}else{
  print "this is userdat:$userdat:\n";
  $userdat="";
  #die "this should never happen, maybe uerdat flagged but not given\n";
}

#create tmp directories
mkdir $tmpdir;

#write out the database version to a file
$efidbmod=~/(\d+)$/;
print "database version is $1 of $efidbmod\n";
system("echo $1 >$tmpdir/database_version");

#get sequences and annotations, tax id code is different, so it is exclusive
#creates fasta and struct.out files
print "userfasta $userfasta\n";
if($pfam or $ipro or $ssf or $gene3d or ($userfasta=~/\w+/ and !$taxid)){
  #make the qsub file
  open(QSUB,">$tmpdir/initial_import.sh") or die "could not create blast submission script $tmpdir/createdb.sh\n";
  print QSUB "#!/bin/bash\n";
  print QSUB "#PBS -j oe\n";
  print QSUB "#PBS -S /bin/bash\n";
  print QSUB "#PBS -q $queue\n";
  print QSUB "#PBS -l nodes=1:ppn=1\n";
  print QSUB "module load $efiestmod\n";
  print QSUB "cd $ENV{PWD}/$tmpdir\n";
  print QSUB "which perl\n";
  print QSUB "$toolpath/getsequence-domain.pl -domain $domain $userfasta -ipro $ipro -pfam $pfam -ssf $ssf -gene3d $gene3d -out ".$ENV{PWD}."/$tmpdir/allsequences.fa -maxsequence $maxsequence -fraction $fraction -access ".$ENV{PWD}."/$tmpdir/accession.txt\n";
  print QSUB "$toolpath/getannotations.pl $userdat -out ".$ENV{PWD}."/$tmpdir/struct.out -fasta ".$ENV{PWD}."/$tmpdir/allsequences.fa\n";
  close QSUB;

  #submit and keep the job id for next dependancy
  $importjob=`qsub $ENV{PWD}/$tmpdir/initial_import.sh`;
  print "import job is:\n $importjob";
  @importjobline=split /\./, $importjob;

}elsif($taxid){
  #create taxid qsub file
  open(QSUB,">$tmpdir/initial_import.sh") or die "could not create blast submission script $tmpdir/createdb.sh\n";
  print QSUB "#!/bin/bash\n";
  print QSUB "#PBS -j oe\n";
  print QSUB "#PBS -S /bin/bash\n";
  print QSUB "#PBS -q $queue\n";
  print QSUB "#PBS -l nodes=1:ppn=1\n";
  print QSUB "module load $efiestmod\n";
  print QSUB "cd $ENV{PWD}/$tmpdir\n";
  print QSUB "$toolpath/getseqtaxid.pl -fasta allsequences.fa -struct struct.out -taxid $taxid\n";
  if($userfasta=~/\w+/){
    $userfasta=~s/^-userfasta //;
    print QSUB "cat $userfasta >> allsequences.fa\n";
  }
  if($userdat=~/\w+/){
    $userdat=~s/^-userdat //;
    print QSUB "cat $userdat >>struct.out\n";
  }
  close QSUB;

  #submit job and keep job id for next dependancy
  $importjob=`qsub $ENV{PWD}/$tmpdir/initial_import.sh`;
  print "import job is:\n $importjob";
  @importjobline=split /\./, $importjob;
}else{
  die "Error Submitting Import Job\n$importjob\nYou cannot mix ipro, pfam, ssf, and gene3d databases with taxid\n";
}

#if multiplexing is on, run an initial cdhit to get a reduced set of "more" unique sequences
#if not, just copy allsequences.fa to sequences.fa so next part of program is set up right
open(QSUB,">$tmpdir/multiplex.sh") or die "could not create blast submission script $tmpdir/multiplex.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@importjobline[0]\n"; 
print QSUB "module load $efiestmod\n";
#  print QSUB "module load blast\n";
print QSUB "cd $ENV{PWD}/$tmpdir\n";
if($multiplexing eq "on"){
  print QSUB "cd-hit -c $sim -s $lengthdif -i $ENV{PWD}/$tmpdir/allsequences.fa -o $ENV{PWD}/$tmpdir/sequences.fa\n";
}else{
  print QSUB "cp $ENV{PWD}/$tmpdir/allsequences.fa $ENV{PWD}/$tmpdir/sequences.fa\n";
}
close QSUB;

$muxjob=`qsub $ENV{PWD}/$tmpdir/multiplex.sh`;
print "mux job is:\n $muxjob";
@muxjobline=split /\./, $muxjob;


#break sequenes.fa into $np parts for blast
open(QSUB,">$tmpdir/fracfile.sh") or die "could not create blast submission script $tmpdir/fracfile.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@muxjobline[0]\n"; 
print QSUB "$toolpath/splitfasta.pl -parts $np -tmp ".$ENV{PWD}."/$tmpdir -source $ENV{PWD}/$tmpdir/sequences.fa\n";
close QSUB;

$fracfilejob=`qsub $tmpdir/fracfile.sh`;
print "fracfile job is:\n $fracfilejob";
@fracfilejobline=split /\./, $fracfilejob;

#make the blast database and put it into the temp directory
open(QSUB,">$tmpdir/createdb.sh") or die "could not create blast submission script $tmpdir/createdb.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@fracfilejobline[0]\n";
print QSUB "module load $efiestmod\n";
print QSUB "cd $ENV{PWD}/$tmpdir\n";
if($blast eq 'diamond' or $blast eq 'diamondsensitive'){
  print QSUB "module load diamond\n";
  print QSUB "diamond makedb --in sequences.fa -d database\n";
}else{
  print QSUB "formatdb -i sequences.fa -n database -p T -o T \n";
}
close QSUB;

$createdbjob=`qsub $tmpdir/createdb.sh`;
print "createdb job is:\n $createdbjob";
@createdbjobline=split /\./, $createdbjob;

#generate $np blast scripts for files from fracfile step
open(QSUB,">$tmpdir/blast-qsub.sh") or die "could not create blast submission script $tmpdir/blast-qsub-$i.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -t 1-$np\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
if($blast=~/diamond/){
  print QSUB "#PBS -l nodes=1:ppn=24\n";
}else{
  print QSUB "#PBS -l nodes=1:ppn=1\n";
}
print QSUB "#PBS -W depend=afterok:@createdbjobline[0]\n";
print QSUB "export BLASTDB=$ENV{PWD}/$tmpdir\n";
#print QSUB "module load blast+\n";
#print QSUB "blastp -query  $ENV{PWD}/$tmpdir/fracfile-\${PBS_ARRAYID}.fa  -num_threads 2 -db database -gapopen 11 -gapextend 1 -comp_based_stats 2 -use_sw_tback -outfmt \"6 qseqid sseqid bitscore evalue qlen slen length qstart qend sstart send pident nident\" -num_descriptions 5000 -num_alignments 5000 -out $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.tab -evalue $evalue\n";
print QSUB "module load $efiestmod\n";
if($blast eq "blast"){
  print QSUB "module load blast\n";
  print QSUB "blastall -p blastp -i $ENV{PWD}/$tmpdir/fracfile-\${PBS_ARRAYID}.fa -d $ENV{PWD}/$tmpdir/database -m 8 -e $evalue -b $blasthits -o $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.tab\n";
}elsif($blast eq "blast+"){
  print QSUB "module load blast+\n";
  print QSUB "blastp -query  $ENV{PWD}/$tmpdir/fracfile-\${PBS_ARRAYID}.fa  -num_threads 2 -db database -gapopen 11 -gapextend 1 -comp_based_stats 2 -use_sw_tback -outfmt \"6\" -max_hsps 1 -num_descriptions $blasthits -num_alignments $blasthits -out $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.tab -evalue $evalue\n";
}elsif($blast eq "diamond"){
  print QSUB "module load diamond\n";
  print QSUB "diamond blastp -p 24 -e $evalue -k $blasthits -C $blasthits -q $ENV{PWD}/$tmpdir/fracfile-\${PBS_ARRAYID}.fa -d $ENV{PWD}/$tmpdir/database -a $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.daa\n";
  print QSUB "diamond view -o $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.tab -f tab -a $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.daa\n";
}elsif($blast eq "diamondsensitive"){
  print QSUB "module load diamond\n";
  print QSUB "diamond blastp --sensitive -p 24 -e $evalue -k $blasthits -C $blasthits -q $ENV{PWD}/$tmpdir/fracfile-\${PBS_ARRAYID}.fa -d $ENV{PWD}/$tmpdir/database -a $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.daa\n";
  print QSUB "diamond view -o $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.tab -f tab -a $ENV{PWD}/$tmpdir/blastout-\${PBS_ARRAYID}.fa.daa\n";
}else{
  die "Blast control not set properly.  Can only be blast, blast+, or diamond.\n";
}
close QSUB;


$blastjob=`qsub $tmpdir/blast-qsub.sh`;
print "blast job is:\n $blastjob";
@blastjobline=split /\./, $blastjob;


#join all the blast outputs back together
open(QSUB,">$tmpdir/catjob.sh") or die "could not create blast submission script $tmpdir/catjob.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterokarray:@blastjobline[0]\n"; 
print QSUB "cat $ENV{PWD}/$tmpdir/blastout-*.tab |grep -v '#'|cut -f 1,2,3,4,12 >$ENV{PWD}/$tmpdir/blastfinal.tab\n";
#print QSUB "rm  $ENV{PWD}/$tmpdir/blastout-*.tab\n";
#print QSUB "rm  $ENV{PWD}/$tmpdir/fracfile-*.fa\n";
close QSUB;
$catjob=`qsub $tmpdir/catjob.sh`;
print "Cat job is:\n $catjob";
@catjobline=split /\./, $catjob;


#Remove like vs like and reverse matches
open(QSUB,">$tmpdir/blastreduce.sh") or die "could not create blast submission script $tmpdir/blastreduce.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@catjobline[0]\n"; 
#print QSUB "mv $ENV{PWD}/$tmpdir/blastfinal.tab $ENV{PWD}/$tmpdir/unsorted.blastfinal.tab\n";
print QSUB "$toolpath/alphabetize.pl -in $ENV{PWD}/$tmpdir/blastfinal.tab -out $ENV{PWD}/$tmpdir/alphabetized.blastfinal.tab -fasta $ENV{PWD}/$tmpdir/sequences.fa\n";
print QSUB "sort -T $sortdir -k1,1 -k2,2 -k5,5nr -t\$\'\\t\' $ENV{PWD}/$tmpdir/alphabetized.blastfinal.tab > $ENV{PWD}/$tmpdir/sorted.alphabetized.blastfinal.tab\n";
print QSUB "$toolpath/blastreduce-alpha.pl -blast $ENV{PWD}/$tmpdir/sorted.alphabetized.blastfinal.tab -fasta $ENV{PWD}/$tmpdir/sequences.fa -out $ENV{PWD}/$tmpdir/unsorted.1.out\n";
print QSUB "sort -T $sortdir -k5,5nr -t\$\'\\t\' $ENV{PWD}/$tmpdir/unsorted.1.out >$ENV{PWD}/$tmpdir/1.out\n";
close QSUB;

$blastreducejob=`qsub $tmpdir/blastreduce.sh`;
print "Blastreduce job is:\n $blastreducejob";

@blastreducejobline=split /\./, $blastreducejob;

#if multiplexing is on, demultiplex sequences back so all are present

open(QSUB,">$tmpdir/demux.sh") or die "could not create blast submission script $tmpdir/demux.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@blastreducejobline[0]\n"; 
print QSUB "module load $efiestmod\n";
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

$demuxjob=`qsub $tmpdir/demux.sh`;
print "Demux job is:\n $demuxjob";
@demuxjobline=split /\./, $demuxjob;

#removed in favor of R, comments kept in case someone ever wants to use the pure perl solution
=pod Start comment
#submit the quartiles scripts, should not run until filterjob is finished
#nothing else depends on this scipt
open(QSUB,">$tmpdir/quartalign.sh") or die "could not create blast submission script $tmpdir/quartalign.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $memqueue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@demuxjobline[0]\n"; 
print QSUB "module load $efiestmod\n";
print QSUB "$toolpath/quart-align.pl -blastout $ENV{PWD}/$tmpdir/1.out -align $ENV{PWD}/$tmpdir/alignment_length.png\n";
close QSUB;

$quartalignjob=`qsub $tmpdir/quartalign.sh`;
print "Quartile Align job is:\n $quartalignjob";

open(QSUB,">$tmpdir/quartpid.sh") or die "could not create blast submission script $tmpdir/quartpid.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $memqueue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@demuxjobline[0]\n"; 
print QSUB "#PBS -m e\n";
print QSUB "module load $efiestmod\n";
print QSUB "$toolpath/quart-perid.pl -blastout $ENV{PWD}/$tmpdir/1.out -pid $ENV{PWD}/$tmpdir/percent_identity.png\n";
close QSUB;

$quartpidjob=`qsub $tmpdir/quartpid.sh`;
print "Quartiles Percent Identity job is:\n $quartpidjob";

open(QSUB,">$tmpdir/simplegraphs.sh") or die "could not create blast submission script $tmpdir/simplegraphs.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $memqueue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@demuxjobline[0]\n"; 
print QSUB "module load $efiestmod\n";
print QSUB "$toolpath/simplegraphs.pl -blastout $ENV{PWD}/$tmpdir/1.out -edges $ENV{PWD}/$tmpdir/number_of_edges.png -fasta $ENV{PWD}/$tmpdir/allsequences.fa -lengths $ENV{PWD}/$tmpdir/length_histogram.png -incfrac $incfrac\n";
close QSUB;

$simplegraphjob=`qsub $tmpdir/simplegraphs.sh`;
print "Simplegraphs job is:\n $simplegraphjob";
=cut end comment


#create information for R to make graphs and then have R make them
open(QSUB,">$tmpdir/graphs.sh") or die "could not create blast submission script $tmpdir/graphs.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $memqueue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@demuxjobline[0]\n"; 
print QSUB "#PBS -m e\n";
print QSUB "module load ".$ENV{'EFIESTMOD'}."\n";
print QSUB "module load $efiestmod\n";
print QSUB "$toolpath/R-hdf-graph.py -b $ENV{PWD}/$tmpdir/1.out -f $ENV{PWD}/$tmpdir/rdata.hdf5 -a $ENV{PWD}/$tmpdir/allsequences.fa -i $incfrac\n";
print QSUB "Rscript $toolpath/quart-align-hdf5.r $ENV{PWD}/$tmpdir/rdata.hdf5 $ENV{PWD}/$tmpdir/alignment_length.png\n";
print QSUB "Rscript $toolpath/quart-perid-hdf5.r $ENV{PWD}/$tmpdir/rdata.hdf5 $ENV{PWD}/$tmpdir/percent_identity.png\n";
print QSUB "Rscript $toolpath/hist-hdf5-length.r  $ENV{PWD}/$tmpdir/rdata.hdf5  $ENV{PWD}/$tmpdir/length_histogram.png\n";
print QSUB "Rscript $toolpath/hist-hdf5-edges.r $ENV{PWD}/$tmpdir/rdata.hdf5 $ENV{PWD}/$tmpdir/number_of_edges.png\n";
print QSUB "touch  $ENV{PWD}/$tmpdir/1.out.completed\n";
#print QSUB "rm $ENV{PWD}/$tmpdir/alphabetized.blastfinal.tab $ENV{PWD}/$tmpdir/blastfinal.tab $ENV{PWD}/$tmpdir/sorted.alphabetized.blastfinal.tab $ENV{PWD}/$tmpdir/unsorted.1.out\n";
close QSUB;

$graphjob=`qsub $tmpdir/graphs.sh`;
print "Graph job is:\n $graphjob";

