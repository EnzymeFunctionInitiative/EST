#!/usr/bin/env perl

#version 0.9.2 no changes

#this program will analyze data from a folder created in the generatedata step, the most important parts being the 1.out and struct.out files

#this program creates scripts and submits them on clusters with torque schedulers
#filterblast.pl			Filters 1.out files to remove unwanted information, creates 2.out file
#xgmml_100_create.pl		Creates a truely 100% xgmml (all nodes and edges) from stuct.out and 2.out files
#xgmml_create_al.pl		Creates xgmml repnode networks from struct.out, 2.out, and cdit output
#stats.pl			Displays number of edges and nodes in each xgmml



use Getopt::Long;

$result=GetOptions ("filter=s"  => \$filter,
		    "minval=s"	=> \$minval,
		    "queue=s"	=> \$queue,
		    "tmp=s"	=> \$tmpdir,
		    "maxlen:i"	=> \$maxlen,
		    "minlen:i"	=> \$minlen,
		    "title:s"	=> \$title,
		    "maxfull:i"	=> \$maxfull);

$toolpath=$ENV{'EFIEST'};
$efiestmod=$ENV{'EFIESTMOD'};

$dbver=`head -1 $tmpdir/database_version`;
chomp $dbver;

#minlen and maxlen defaulted to zero if not assigned.
if(defined $minlen){
}else{
  $minlen=0;
}

if(defined $maxfull){
  unless($maxfull=~/^\d+$/){
    die "maxfull must be an integer\n";
  }
}else{
  $maxfull=10000000;
}

if(defined $maxlen){

}else{
  $maxlen=0;
}

#if no filter set to bit
if(defined $filter){

}else{
  $filter="bit";
}

#if no minval, set to 0

if(defined $minval){

}else{
  $minval=0;
}

if(defined $title){
  
}else{
  $title="Untitled";
}

if(defined $queue){
}else{
  $queue="efi";
}

unless(defined $tmpdir){
  die "A temporary directory specified by -tmp is required for the program to run\n";
}

#quit if the xgmml files have been created in this directory
#testing with fullxgmml because I am lazy
if(-s "$tmpdir/$filter-$minval-$minlen-$maxlen/full.xgmml"){
  print "This run appears to have already been completed, exiting\n";
  exit;
}

print "Data from runs will be saved to $tmpdir/$filter-$minval-$minlen-$maxlen/\n";

#dont refilter if it has already been done
unless( -d "$tmpdir/$filter-$minval-$minlen-$maxlen"){
  mkdir "$tmpdir/$filter-$minval-$minlen-$maxlen" or die "could not make analysis folder $tmpdir/$filter-$minval-$minlen-$maxlen\n";

  #submit the job for filtering out extraneous edges

  open(QSUB,">$tmpdir/$filter-$minval-$minlen-$maxlen/filterblast.sh") or die "could not create blast submission script $tmpdir/fullxgmml.sh\n";
  print QSUB "#!/bin/bash\n";
  print QSUB "#PBS -j oe\n";
  print QSUB "#PBS -S /bin/bash\n";
  print QSUB "#PBS -q $queue\n";
  print QSUB "#PBS -l nodes=1:ppn=1\n";
  print QSUB "module load perl/5.16.1\n";
  print QSUB "$toolpath/filterblast.pl -blastin $ENV{PWD}/$tmpdir/1.out -blastout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -fastain $ENV{PWD}/$tmpdir/allsequences.fa -fastaout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/sequences.fa -filter $filter -minval $minval -maxlen $maxlen -minlen $minlen\n";
  close QSUB;

  $filterjob=`qsub $tmpdir/$filter-$minval-$minlen-$maxlen/filterblast.sh`;
  print "Filterblast job is:\n $filterjob";

  @filterjobline=split /\./, $filterjob;
}else{
  print "Using prior filter\n";
}

#submit the job for generating the full xgmml file
#since struct.out is created in the first half, the full and repnode networks can all be generated at the same time
#depends on ffilterblast
    
open(QSUB,">$tmpdir/$filter-$minval-$minlen-$maxlen/fullxgmml.sh") or die "could not create blast submission script $tmpdir/fullxgmml.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@filterjobline[0]\n";
print QSUB "module load $efiestmod\n";
print QSUB "$toolpath/xgmml_100_create.pl -blast=$ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -fasta $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/sequences.fa -struct $ENV{PWD}/$tmpdir/struct.out -out $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/full.xgmml -title=\"$title\" -maxfull $maxfull -dbver $dbver\n";
close QSUB;

#submit generate the full xgmml script, job dependences should keep it from running till blast results have been created all blast out files are combined

$fulljob=`qsub $tmpdir/$filter-$minval-$minlen-$maxlen/fullxgmml.sh`;
print "Full xgmml job is:\n $fulljob";

@fulljobline=split /\./, $fulljob;

#submit series of repnode network calculations
#depends on filterblast

open(QSUB,">$tmpdir/$filter-$minval-$minlen-$maxlen/cdhit.sh") or die "could not create blast submission script $tmpdir/repnodes.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -t 40,45,50,55,60,65,70,75,80,85,90,95,100\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@filterjobline[0]\n";
print QSUB "module load $efiestmod\n";
#print QSUB "module load cd-hit\n";
print QSUB "CDHIT=\$(echo \"scale=2; \${PBS_ARRAYID}/100\" |bc -l)\n";
print QSUB "cd-hit -i $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/sequences.fa -o $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/cdhit\$CDHIT -n 2 -c \$CDHIT -d 0\n";
print QSUB "$toolpath/xgmml_create_all.pl -blast $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -cdhit $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/cdhit\$CDHIT.clstr -fasta $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/allsequences.fa -struct $ENV{PWD}/$tmpdir/struct.out -out $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/repnode-\$CDHIT.xgmml -title=\"$title\" -dbver $dbver\n";
close QSUB;

#submit the filter script, job dependences should keep it from running till all blast out files are combined
$repnodejob=`qsub $tmpdir/$filter-$minval-$minlen-$maxlen/cdhit.sh`;
print "Repnodes job is:\n $repnodejob";


@repnodejobline=split /\./, $repnodejob;

#test to fix dependancies
#depends on cdhit.sh
open(QSUB,">$tmpdir/$filter-$minval-$minlen-$maxlen/fix.sh") or die "could not create blast submission script $tmpdir/repnodes.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterokarray:@repnodejobline[0]\n";
print QSUB "module load $efiestmod\n";
print QSUB "sleep 5\n";
close QSUB;

#submit the filter script, job dependences should keep it from running till all blast out files are combined

$fixjob=`qsub $tmpdir/$filter-$minval-$minlen-$maxlen/fix.sh`;
print "Fix job is:\n $fixjob";
@fixjobline=split /\./, $fixjob;

#submit series of repnode network calculations
#depends on filterblast
open(QSUB,">$tmpdir/$filter-$minval-$minlen-$maxlen/stats.sh") or die "could not create blast submission script $tmpdir/repnodes.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "#PBS -W depend=afterok:@fulljobline[0]:$fixjobline[0]\n";
#print QSUB "#PBS -W depend=afterok:@fulljobline[0]\n"; 
print QSUB "#PBS -m e\n";
print QSUB "module load $efiestmod\n";
print QSUB "$toolpath/stats.pl -tmp $ENV{PWD}/$tmpdir -run $filter-$minval-$minlen-$maxlen -out $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/stats.tab\n";
close QSUB;

#submit the filter script, job dependences should keep it from running till all blast out files are combined
$statjob=`qsub $tmpdir/$filter-$minval-$minlen-$maxlen/stats.sh`;
print "Stats job is:\n $statjob";