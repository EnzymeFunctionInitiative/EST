#!/usr/bin/env perl

#version 0.9.2 no changes

#filters out extra data based on sequence length (minlen, maxlen) or the value of some specifed filter (eval pid or bit)

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
    #my $log=-(log(@line[3])/log(10))+@line[12]*log(2)/log(10);
    my $log=int(-(log(@line[5]*@line[6])/log(10))+@line[4]*log(2)/log(10));
    if($log>=$minval and @line[5]>=$minlen and @line[6]>=$minlen and ((@line[5]<=$maxlen and @line[6]<=$maxlen) or $maxlen==0)){
      print OUT "$origline";
    }elsif($log<$minval){
      last;
    }
  }elsif($bitscore){
    if(@line[4]>=$minval and @line[5]>=$minlen and @line[6]>=$minlen and ((@line[5]<=$maxlen and @line[5]<=$maxlen) or $maxlen==0)){
      print OUT "$origline";
    }elsif(@line[2]<$minval){
      last;
    }
  }elsif($pid){
    if(@line[2]>=$minval and @line[5]>=$minlen and @line[6]>=$minlen and ((@line[5]<=$maxlen and @line[6]<=$maxlen) or $maxlen==0)){
      print OUT "$origline";
    }
  }
}
close OUT;
close BLAST;

open FASTAIN, $fastain or die "Cannot open fasta file $fastain\n";
open FASTAOUT, ">$fastaout" or die "Cannot write to fasta file $fastaout\n";
my $sequence = "";
my @seqLines; # keep track of individual lines in the sequence since we write them out as they come in
my $key = "";
while (<FASTAIN>){
  my $line = $_;
  chomp $line;
  if ($line =~ /^>/) {
    if (length $sequence >= $minlen and (length $sequence <= $maxlen or $maxlen == 0)) { 
      print FASTAOUT "$key\n", join("\n", @seqLines), "\n\n";
    }
    $key = $line;
    $sequence = "";
    @seqLines = ();
  } else {
    $sequence .= $line;
    push @seqLines, $line;
  }
}
print FASTAOUT "$key\n", join("\n", @seqLines), "\n\n";
close FASTAOUT;
close FASTAIN;

