#!/usr/bin/env perl

use Getopt::Long;

$result=GetOptions ("run=s"	=> \$run,
		    "tmp=s"	=> \$tmpdir,
		    "out=s"	=> \$out);

opendir(DIR, "$tmpdir/$run") or die "Cannot open directory $tmpdir/$run\n";
open(OUT, ">$out") or die "cannot write to $out\n";
print OUT "File\t\t\tNodes\tEdges\tSize\n";
foreach $file (sort {$a cmp $b} readdir(DIR)){
#print "$file\n";
  if($file=~/.xgmml$/){
    if(-s "$tmpdir/$run/$file"){
      $size=-s "$tmpdir/$run/$file";
      $nodes=`grep "^  <node" $tmpdir/$run/$file|wc -l`;
      $edges=`grep "^  <edge" $tmpdir/$run/$file|wc -l`;
      chomp $nodes;
      chomp $edges;
      if($file=~/^full/){
	$file.="\t";
      }
      print OUT "$file\t$nodes\t$edges\t$size\n"
    }else{
      print OUT "$file\t0\t0\t0\n";
    }
  }
}

close DIR;

system("touch $out.completed");