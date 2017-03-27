#!/usr/bin/env perl

use Getopt::Long;
use File::Copy;
use File::Slurp;
use DBD::SQLite;
use DBD::mysql;

$result=GetOptions ("xgmml=s"		=> \$xgmml,
		    "oldtmp=s"		=> \$oldtmp,
		    "newtmp=s"		=> \$newtmp);

$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
eval $configfile;
$combined=$data_files."/combined.fasta";
#$perpass=1000;
#print "$configfile\n";
print "pass size $perpass\n";


#system("cp $oldtmp/1.out $newtmp/1.out");
#system("cp $oldtmp/struct.out $newtmp/struct.out");
print "Make directories\n";
#mkdir $newtmp or die "Could not make new tmp directory\n";
#copy("$oldtmp/1.out", "$newtmp/1.out") or die "Copy failed: $!\n";
#copy("$oldtmp/struct.out", "$newtmp/struct.out") or die "Copy failed: $!\n";
print "parse xgmml for accessions\n";
#gather accessions from xgmml file
@allaccessions=();
open(XGMML, $xgmml) or die "cannot open xgmml file";
while( <XGMML> ){
  $line.=$_;
  if($line=~/<edge/){
    last;
  }
  chomp $line;
  if($line=~/<\/node>/){
#print "$line\n";
    if($line=~/<att type="list" name="ACC">(.*?)<\/att>/ or $line=~/<att name="ACC" type="list">(.*?)<\/att>/){
      $acc=$1;
#print "Match ACC\t$acc\n";
      push @accessions, $acc=~/value=\"(\w{6,10})\"/g;
      #$acc=~/value="(\w{6})"/g;
#print "match: $1\n\ncount ".scalar @accessions."\n";      
      $line="";
    }
  }else{
    #print "\t$line\n";
  }
}   
close XGMML;

print "found ".scalar @accessions." accessions in xgmml\n";
@allaccessions=@accessions;

print "Fetch fasta sequences\n";
#create sequences.fa file from accessions
open(FASTA, ">$newtmp/allsequences.fa");
while(scalar @accessions){
  @batch=splice(@accessions, 0, $perpass);
  $batchline=join ',', @batch;
  #print "fastacmd -d $combined -s $batchline\n";
  print "Get next $perpass sequences\n";
  #print "fastacmd -d $combined -s $batchline\n";
  @sequences=split /\n/, `fastacmd -d $combined -s $batchline`;
  foreach $sequence (@sequences){ 
    $sequence=~s/^>\w\w\|(\w{6,10}).*/>$1/;
    print FASTA "$sequence\n";
    #print "$sequence\n";
  } 
}
close FASTA;

print "Parse 1.out for edges\n";
foreach $accession (@allaccessions){
  $acchash{$accession}=1;
}
open(OLDBLAST, "$oldtmp/1.out") or die "Could not open blast file in original folder\n";
open(NEWBLAST, ">$newtmp/1.out") or die "Could not write to new blast file\n";
while(<OLDBLAST>){
  $line=$_;
  chomp $line;
  @aryline=split /\t/, $line;
  if($acchash{@aryline[0]} and $acchash{@aryline[1]}){
    print NEWBLAST "$line\n";
  }
}
close OLDBLAST;
close NEWBLAST;
print "Parse struct.out for nodes\n";
open(OLDSTRUCT, "$oldtmp/struct.out") or die "Could not open old struct.out\n";
open(NEWSTRUCT, ">$newtmp/struct.out") or die "Could not write to new struct.out\n";
$write=0;
while(<OLDSTRUCT>){
  $line=$_;
  if($line=~/^(\w+)/){
    if($acchash{$1}){
      print NEWSTRUCT $line;
      $write=1;
    }else{
      $write=0;
    }
  }else{
    if($write){
      print NEWSTRUCT $line;
    }
  }
}
close OLDSTRUCT;
close NEWSTRUCT;
print "done\n";