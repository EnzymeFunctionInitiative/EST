#!/usr/bin/env perl

use Getopt::Long;

$result=GetOptions ("blastin=s"	=> \$blast,
		    "blastout=s"=> \$out,
		    "filter=s"  => \$filter,
		    "minlen=s"	=> \$minlen,
		    "maxlen=s"	=> \$maxlen,
		    "minval=s"	=> \$minval,
		    "fastain=s"	=> \$fastain,
		    "fastaout=s"=> \$fastaout);

%sequences=();

if($filter=~/^eval$/){
  $evalue=1;
  $bitscore=$pid=0;
}elsif($filter=~/^bit$/){
  $bitscore=1;
  $evalue=$pid=0;
}elsif($filter=~/^pid$/){
  $minval=$minval/100;
  $pid=1;
  $evalue=$bitscore=0;
}

if(defined $minlen){
}else{
  $minlen=0;
}

if(defined $maxlen){

}else{
  $maxlen=0;
}

unless(defined $minval and $minval >= 0){
  die "you must specify a minimum value to filter that is >= zero\n";
}

if(!(defined $filter) or !($evalue or $bitscore or $pid)){
  die "you must specify a filter of either: eval, bit, or pid\n";
}

unless(defined $out){
  die "you must specify an output file with -out\n";
}

unless(defined $blast){
  die "you must specify an input blast file with -blast\n";
}



open BLAST, $blast or die "cannot open blast output file $blast\n";
open OUT, ">$out" or die "cannot write to output file $out\n";
while (<BLAST>){
  $line=$_;
  $origline=$line;
  chomp $line;
  my @line=split /\t/, $line;
  if($evalue){
    my $log=-(log(@line[3])/log(10))+@line[2]*log(2)/log(10);
    if($log>=$minval and @line[10]>=$minlen and @line[11]>=$minlen and ((@line[10]<=$maxlen and @line[11]<=$maxlen) or $maxlen==0)){
      print OUT "$origline";
    }
  }elsif($bitscore){
    if(@line[2]>=$minval and @line[10]>=$minlen and @line[11]>=$minlen and ((@line[10]<=$maxlen and @line[11]<=$maxlen) or $maxlen==0)){
      print OUT "$origline";
    }
  }elsif($pid){
    if(@line[5]>=$minval and @line[10]>=$minlen and @line[11]>=$minlen and ((@line[10]<=$maxlen and @line[11]<=$maxlen) or $maxlen==0)){
      print OUT "$origline";
    }
  }
}
close OUT;
close BLAST;

open FASTAIN, $fastain or die "Cannot open fasta file $fastain\n";
open FASTAOUT, ">$fastaout" or die "Cannot write to fasta file $fastaout\n";
$sequence="";
while (<FASTAIN>){
  $line=$_;
  chomp $line;
  if($line=~/^>/){
    if(length $sequence>= $minlen and (length $sequence <= $maxlen or $maxlen==0)){ 
      print FASTAOUT "$key\n$sequence";
    }
    $key=$line;
    $sequence="";
  }else{
    $sequence.="$line\n";
  }
}
print FASTAOUT "$key\n$sequence\n";
close FASTAOUT;
close FASTAIN;

