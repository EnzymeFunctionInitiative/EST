#!/usr/bin/env perl

#this is just a qsub wrapper for regen-network.pl
use Getopt::Long;

$result=GetOptions ("xgmml=s"		=> \$xgmml,
		    "oldtmp=s"		=> \$oldtmp,
		    "newtmp=s"		=> \$newtmp,
		    "queue=s"		=> \$queue);

$toolpath=$ENV{'EFIEST'};
$efiestmod=$ENV{'EFIESTMOD'};

unless($xgmml=~/^\//){
  $xgmml="$ENV{PWD}/$xgmml";
}

unless($oldtmp=~/^\//){
  $oldtmp="$ENV{PWD}/$oldtmp";
}

unless($newtmp=~/^\//){
  $newtmp="$ENV{PWD}/$newtmp";
}

unless($queue=~/\w/){
  $queue="default";
}

mkdir $newtmp or die "cannnot create new temporary directory $newtmp\n";

open(QSUB,">$newtmp/regen-network.sh") or die "could not create blast submission script $tmpdir/regen-network.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "module load $efiestmod\n";
print QSUB "$toolpath/regen-network.pl -oldtmp $oldtmp -newtmp $newtmp -xgmml $xgmml\n";
close QSUB;

#submit generate the full xgmml script, job dependences should keep it from running till blast results have been created all blast out files are combined

$regenjob=`qsub $newtmp/regen-network.sh`;
print "Job to regen network is is:\n $regenjob";
