#!/usr/bin/env perl

use strict;

# Merge separated UniRef 50 and 90 tables into one.


my $ur50 = shift;
my $ur90 = shift;
my $out = shift;


my %data;

open UR50, $ur50;
while (<UR50>) {
    chomp;
    my ($ur, $id) = split /\t/;
    $data{$id}->[0] = $ur;
}
close UR50;

open UR90, $ur90;
while (<UR90>) {
    chomp;
    my ($ur, $id) = split /\t/;
    $data{$id}->[1] = $ur;
}
close UR90;



open OUT, ">$out" or die "Nope: $!";

foreach my $id (sort keys %data) {
    print OUT join("\t", $id,
                     ($data{$id}->[0] ? $data{$id}->[0] : ""),
                     ($data{$id}->[1] ? $data{$id}->[1] : "")), "\n";
}

close OUT;

