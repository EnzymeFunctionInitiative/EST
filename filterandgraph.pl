#!/usr/bin/env perl

#version 0.9.2 no changes

#this program allows you to filter the results of generatedata and see the graph results

#this program creates scrpts and submit them on clusters with torque that use the following perl files
#filterblast.pl			Filters 1.out files to remove unwanted information, creates 2.out file
#quart-align.pl			generates the alignment length quartile graph
#quart-perid.pl			generates the percent identity quartile graph
#sipmlegraphs.pl		generates sequence length and alignment score distributions

use Getopt::Long;

$result=GetOptions ("filter=s"  => \$filter,
		    "minval=s"	=> \$minval,
		    "queue=s"	=> \$queue,
		    "tmp=s"	=> \$tmpdir,
		    "maxlen=i"	=> \$maxlen,
		    "minlen=i"	=> \$minlen,
		    "incfrac=f"	=> \$incfrac);


$toolpath=$ENV{'EFIEST'};
$efiestmod=$ENV{'EFIESTMOD'};
#$toolpath="/home/groups/efi/devel";
$graphmultiplier=1.4;
$xinfo=500;
#$queue.=" -l nodes=compute-4-0";

#because variable values are important for filterblast and creating folder names we need to set defaults

#minlen and maxlen defaulted to zero if not assigned.
if(defined $minlen){
}else{
  $minlen=0;
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

#if no minval, set to zero

if(defined $minval){

}else{
  $minval=0;
}


if(defined $queue){
}else{
  $queue="default";
}
print "queue is $queue\n";

if(defined $incfrac){
}else{
  $incfrac=.99;
}
print "incfrac is $incfrac\n";


#quit if the xgmml files have been created in this directory
#testing with percent_identity.png because I am lazy
if(-s "$tmpdir/$filter-$minval-$minlen-$maxlen/percent_identity.png"){
  print "Graphs appears to have already been completed, exiting\n";
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
  print QSUB "module load $efiestmod\n";
  print QSUB "$toolpath/filterblast.pl -blastin $ENV{PWD}/$tmpdir/1.out -blastout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -fastain $ENV{PWD}/$tmpdir/sequences.fa -fastaout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/sequences.fa -filter $filter -minval $minval -maxlen $maxlen -minlen $minlen\n";
  close QSUB;

  $filterjob=`qsub $tmpdir/$filter-$minval-$minlen-$maxlen/filterblast.sh`;
  print "Filterblast job is:\n $filterjob";

  @filterjobline=split /\./, $filterjob;
}else{
  print "Using prior filter\n";
}

#submit the quartiles scripts, should not run until filterjob is finished
#nothing else depends on this scipt

open(QSUB,">$tmpdir/$filter-$minval-$minlen-$maxlen/quartalign.sh") or die "could not create blast submission script $tmpdir/$filter-$minval-$minlen-$maxlen/quartalign.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
if(defined $filterjob){
  print QSUB "#PBS -W depend=afterok:@filterjobline[0]\n"; 
}
print QSUB "module load $efiestmod\n";
print QSUB "$toolpath/quart-align.pl -blastout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -align $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/alignment_length.png\n";
close QSUB;

$quartalignjob=`qsub $tmpdir/$filter-$minval-$minlen-$maxlen/quartalign.sh`;
print "Quartile Align job is:\n $quartalignjob";

open(QSUB,">$tmpdir/$filter-$minval-$minlen-$maxlen/quartpid.sh") or die "could not create blast submission script $tmpdir/$filter-$minval-$minlen-$maxlenr/quartpid.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
if(defined $filterjob){
  print QSUB "#PBS -W depend=afterok:@filterjobline[0]\n"; 
} 
print QSUB "#PBS -m e\n";
print QSUB "module load $efiestmod\n";
print QSUB "$toolpath/quart-perid.pl -blastout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -pid $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/percent_identity.png\n";
close QSUB;

$quartpidjob=`qsub $tmpdir/$filter-$minval-$minlen-$maxlen/quartpid.sh`;
print "Quartiles Percent Identity job is:\n $quartpidjob";

open(QSUB,">$tmpdir/$filter-$minval-$minlen-$maxlen/simplegraphs.sh") or die "could not create blast submission script $tmpdir/$filter-$minval-$minlen-$maxlen/simplegraphs.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
if(defined $filterjob){
  print QSUB "#PBS -W depend=afterok:@filterjobline[0]\n"; 
}
print QSUB "module load $efiestmod\n";
print QSUB "$toolpath/simplegraphs.pl -blastout $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/2.out -maxlen $maxlen -minlen $minlen -edges $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/number_of_edges.png -fasta $ENV{PWD}/$tmpdir/sequences.fa -lengths $ENV{PWD}/$tmpdir/$filter-$minval-$minlen-$maxlen/length_histogram.png -incfrac $incfrac\n";
close QSUB;

$simplegraphjob=`qsub $tmpdir/$filter-$minval-$minlen-$maxlen/simplegraphs.sh`;
print "Simplegraphs job is:\n $simplegraphjob";