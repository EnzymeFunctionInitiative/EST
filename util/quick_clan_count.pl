#!/usr/bin/env perl

use strict;

use FindBin;
use Getopt::Long;
use List::MoreUtils qw(uniq);


my ($inputFile, $clanFile); 

GetOptions(
    "fam=s"         => \$inputFile,
    "clans=s"       => \$clanFile,
);


my %clanData;
my %famToClan;

open CLANS, $clanFile or die "Unable to open $clanFile: $!";

while (<CLANS>) {
    chomp;
    my ($fam, $clan, @stuff) = split /\t/;
    next if not $clan;

    $clanData{$clan} = {fams => [], ids => [], ur50 => [], ur90 => []} if not exists $clanData{$clan};
    push @{$clanData{$clan}->{fams}}, $fam;
    $famToClan{$fam} = $clan;
}

close CLANS;





open FAM, $inputFile or die "Unable to open $inputFile: $!";

while (<FAM>) {
    chomp;
    my ($fam, $acc, $s, $e, $ur50, $ur90) = split /\t/;

    next if not exists $famToClan{$fam};

    my $clan = $famToClan{$fam};
    
    push @{ $clanData{$clan}->{ids} }, $acc;
    push @{ $clanData{$clan}->{ur50} }, $ur50;
    push @{ $clanData{$clan}->{ur90} }, $ur90;
}

close FAM;



foreach my $clan (sort keys %clanData) {
    my @allIds = @{ $clanData{$clan}->{ids} };
    my @ids = uniq @allIds;
    my @ur50 = uniq @{ $clanData{$clan}->{ur50} };
    my @ur90 = uniq @{ $clanData{$clan}->{ur90} };
    my @fams = @{ $clanData{$clan}->{fams} };
    print join("\t", $clan, scalar(@fams), scalar(@allIds), scalar(@ids), scalar(@ur50), scalar(@ur90)), "\n";
}



