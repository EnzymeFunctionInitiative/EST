#!/usr/bin/env perl

#program to re-add sequences removed by initial cdhit
#version 0.9.3 Program created

use strict;

use FindBin;
use Getopt::Long;
use lib "$FindBin::Bin/lib";
use CdHitParser;


my ($cluster, $blastin, $blastout);
my $result = GetOptions(
    "cluster=s"     => \$cluster,
    "blastin=s"     => \$blastin,
    "blastout=s"    => \$blastout
);

#parse cluster file to get parent/child sequence associations

#create new 1.out file from input 1.out that populates associations

open CLUSTER, $cluster or die "cannot open cdhit cluster file $cluster\n";
open BLASTIN, $blastin or die "cannot open blast input file $blastin\n";
open BLASTOUT, ">$blastout" or die "cannnot write to blast output file $blastout\n";

my $cp = new CdHitParser(verbose => 1);

#%tree=();

#parse the clstr file
print "Read in clusters\n";
my $line = "";
while (<CLUSTER>) {
    print "$line";
    $line=$_;
    chomp $line;
    $cp->parse_line($line);
#    if($line=~/^>/){
#        #print "New Cluster\n";
#        if(defined $head){
#            @{$tree{$head}}=@children;
#        }
#        @children=();
#    }elsif($line=~/ >(\w{6,10})\.\.\. \*$/ or $line=~/ >(\w{6,10}:\d+:\d+)\.\.\. \*$/ ){
#        #print "head\t$1\n";
#        push @children, $1;
#        $head=$1;
#        #print "$1\n";
#    }elsif($line=~/^\d+.*>(\w{6,10})\.\.\. at/ or $line=~/^\d+.*>(\w{6,10}:\d+:\d+)\.\.\. at/){
#        print "$head\tchild\t$1\n";
#        push @children, $1;
#    }else{
#        warn "no match in $line\n";
#    }
}

#@{$tree{$head}}=@children;
$cp->finish;


print "Demultiplex blast\n";
#read BLASTIN and expand with clusters from cluster file to create demultiplexed file
while (my $line = <BLASTIN>) {
    chomp $line;
    my @lineary=split /\s+/, $line;
    my $linesource=shift @lineary;
    my $linetarget=shift @lineary;
    #print "$linesource\t$linetarget\n";
    my @srcChildren = $cp->get_children($linesource);
    if ($linesource eq $linetarget) {
        for (my $i=0; $i < scalar @srcChildren; $i++) {
            for (my $j = $i+1; $j < scalar @srcChildren; $j++) {
                print BLASTOUT join("\t", $srcChildren[$i], $srcChildren[$j], @lineary), "\n";
                print "likewise demux\t", $srcChildren[$i], $srcChildren[$j], "\n";
            }
        }
    } else {
        foreach my $source (@srcChildren) {
            foreach my $target ($cp->get_children($linetarget)) {
                print BLASTOUT join("\t", $source, $target, @lineary), "\n";
            }
        }
    }
}

