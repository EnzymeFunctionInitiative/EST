#!/usr/bin/env perl
use strict;
use warnings;

# filters out connections based on the input file

use Getopt::Long;


my ($blast, $out, $customClusterFile);
my $result = GetOptions(
    "blastin=s"                 => \$blast,
    "blastout=s"                => \$out,
    "custom-cluster-file=s"     => \$customClusterFile,
);



if (not defined $customClusterFile or not -f $customClusterFile) {
    die "you must specify an input custom cluster mapping file (-custom-cluster-file)";
}

unless (defined $out) {
    die "you must specify an output file with -blastout";
}

unless (defined $blast) {
    die "you must specify an input blast file with -blastin";
}


my $mapping = loadClusterMapping($customClusterFile);



open BLAST, $blast or die "cannot open blast output file $blast\n";
open OUT, ">$out" or die "cannot write to output file $out\n";

while (my $line = <BLAST>){
    my $origline = $line;
    chomp $line;
    my ($queryId, $subjectId, @rest) = split /\t/, $line;

    if (exists $mapping->{$queryId} and exists $mapping->{$subjectId} and $mapping->{$queryId} eq $mapping->{$subjectId}) {
        print "Found connection between $queryId - $subjectId\n";
        print OUT $origline;
    } else {
        print "Excluding $queryId - $subjectId\n";
    }
}

close OUT;
close BLAST;






sub loadClusterMapping {
    my $file = shift;

    my %data;

    open MAP, $file or die "Unable to read cluster map file $file: $!";

    my $firstLine = 1;
    while (my $line = <MAP>) {
        chomp $line;
        my ($id, $clusterId, @rest) = split(m/[\s,]+/, $line);
        
        if (!(length($id) == 6 or length($id) == 10) or $id !~ m/[A-Z0-9]/i) {
            next if $firstLine; # if the ID isn't proper, and this is the first line we assume that this row is the column header.
            print STDERR "Invalid ID format ($id $clusterId); do you have the protein ID in the first column and the cluster number in the second?\n";
            next;
        }
        $firstLine = 0;
        $data{$id} = $clusterId;
    }

    close MAP;

    return \%data;
}


