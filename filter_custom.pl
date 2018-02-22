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



if (not defined $customClusterFile and not -f $customClusterFile) {
    die "you must specify an input custom cluster mapping file.";
}

unless (defined $out) {
    die "you must specify an output file with -out";
}

unless (defined $blast) {
    die "you must specify an input blast file with -blast";
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

    while (my $line = <MAP>) {
        chomp $line;
        my ($id, $clusterId, @rest) = split(m/\t/, $line);
        die "Invalid ID format; do you have the protein ID in the first column and the cluster number in the second?"
            if length($id) != 6 and length($id) != 10;
        $data{$id} = $clusterId;
    }

    close MAP;

    return \%data;
}


