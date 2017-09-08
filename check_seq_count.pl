#!/usr/bin/env perl

# Verify that the number of the clusters/nodes are within the limit specified.

use strict;
use Getopt::Long;


my ($cluster, $maxSeq, $errorFile);
my $result = GetOptions(
    "cluster=s"     => \$cluster,
    "max-seq=i"     => \$maxSeq,
    "error-file=s"  => \$errorFile,
);

if (not -f $cluster) {
    die "-cluster file_path argument must be provided.";
}
if (not $errorFile) {
    die "-error-file file_path argument must be provided.";
}
if (not defined $maxSeq) {
    die "-max-seq max_num_seq argument must be provided.";
}

my $numClusters = `grep \\>Cluster $cluster | wc -l`;
$numClusters =~ s/\s//g;

if ($maxSeq > 0 and $numClusters > $maxSeq) {
    open ERROR, ">$errorFile" or die "cannot write error output file $errorFile";
    print ERROR "Number of sequences $numClusters exceeds maximum specified $maxSeq\n";
    close ERROR;
    die "Number of sequences $numClusters exceeds maximum specified $maxSeq";
}



