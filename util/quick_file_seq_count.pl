#!/usr/bin/env perl
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Biocluster::Database;
use Getopt::Long;


my ($inputFile); 

GetOptions(
    "input=s"           => \$inputFile,
);


my %data;


open FILE, $inputFile or die "Unable to open $inputFile: $!";

while (<FILE>) {
    chomp;
    
    my ($fam, $acc, $s, $e, $ur50, $ur90) = split /\t/;
    if (not exists $data{$fam}) {
        $data{$fam} = {
            full => {
                count => 0,
                ids => {},
            },
            ur50 => {
                count => 0,
                ids => {},
            },
            ur90 => {
                count => 0,
                ids => {},
            }
        };
    }

    if (not exists $data{$fam}->{full}->{ids}->{$acc}) {
        $data{$fam}->{full}->{ids}->{$acc} = 1;
        $data{$fam}->{full}->{count}++;
    }
    if (not exists $data{$fam}->{ur50}->{ids}->{$ur50}) {
        $data{$fam}->{ur50}->{ids}->{$ur50} = 1;
        $data{$fam}->{ur50}->{count}++;
    }
    if (not exists $data{$fam}->{ur90}->{ids}->{$ur90}) {
        $data{$fam}->{ur90}->{ids}->{$ur90} = 1;
        $data{$fam}->{ur90}->{count}++;
    }
}

close FILE;


foreach my $fam (sort keys %data) {
    print join("\t", $fam, $data{$fam}->{full}->{count}, $data{$fam}->{ur50}->{count}, $data{$fam}->{ur90}->{count}), "\n";
}



