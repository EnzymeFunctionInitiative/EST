#!/usr/bin/env perl

#program to re-add sequences removed by initial cdhit
#version 0.9.3 Program created

use strict;

use List::MoreUtils qw(uniq);
use FindBin;
use Getopt::Long;
use lib "$FindBin::Bin/lib";
use CdHitParser;


my ($cluster, $seqId, $seqLen);
my $result = GetOptions(
    "cluster=s"     => \$cluster,
    "id=s"          => \$seqId,
    "len=s"         => \$seqLen,
);




my $cp = new CdHitParser();

#parse cluster file to get parent/child sequence associations
open CLUSTER, $cluster or die "cannot open cdhit cluster file $cluster\n";

my $line = "";
while (<CLUSTER>) {
    $line=$_;
    chomp $line;
    $cp->parse_line($line);
}
$cp->finish;

close CLUSTER;


print join("\t", $seqId, $seqLen, scalar($cp->get_clusters)), "\n";


