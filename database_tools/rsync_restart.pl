#!/bin/env perl

use strict;

use Capture::Tiny qw(:all);

die `rsync` if scalar @ARGV < 3;

my $maxNumTries = 5;
if ($ARGV[0] =~ /NT/) {
    ($maxNumTries = $ARGV[0]) =~ s/NT//;
    shift @ARGV;
}


my $completed = 0;
my $tries = 1;
while (not $completed and $tries <= $maxNumTries) {
    my $stderr;
    (undef, $stderr) = tee {
        system("rsync", @ARGV);
    };

    if (not $stderr) {
        $completed = 1;
    }

    $tries++;
}

