#!/usr/bin/env perl

# This removes all nodes from the struct.out file that have been filtered out by the cd-hit
# process.

use strict;

use FindBin;
use Getopt::Long;
use lib "$FindBin::Bin/lib";
use CdHitParser;


my ($cluster, $structIn, $structOut);
my $result = GetOptions(
    "cluster=s"     => \$cluster,
    "out=s"         => \$structOut,
    "in=s"          => \$structIn,
);

my $cp = new CdHitParser();

#parse cluster file to get parent/child sequence associations
open CLUSTER, $cluster or die "cannot open cdhit cluster file $cluster\n";

print "Read in clusters\n";
my $line = "";
while (<CLUSTER>) {
    $line=$_;
    chomp $line;
    $cp->parse_line($line);
}
$cp->finish;

close CLUSTER;


my %remove;
foreach my $clusterId ($cp->get_clusters) {
    foreach my $child ($cp->get_children($clusterId)) {
        $remove{$child} = 1 if $child ne $clusterId;
    }
}

open IN, $structIn or die "Cannot open input struct file $structIn: $!";
open OUT, ">$structOut" or die "cannnot open output struct file $structOut: $!";

my $curNode = "";

while (<IN>) {
    if (/^([A-Z0-9:]+)/) {
        $curNode = $1;
    }
    print OUT if not exists $remove{$curNode};
}

close OUT;
close IN;


