#!/bin/env perl

use strict;
use warnings;

use FindBin;
use Getopt::Long;
use Data::Dumper;

use lib "$FindBin::Bin/lib";
use NeighborhoodConnectivity;
use CdHitParser;


my ($inputBlast, $inputXgmml, $output, $includeMeta, $cdhit);
my $result = GetOptions(
    "input-blast=s"     => \$inputBlast,
    "input-xgmml=s"     => \$inputXgmml,
    "output-map=s"      => \$output,
    "include-meta"      => \$includeMeta,
    "cdhit=s"           => \$cdhit,
);

die "Need --input-blast blast file OR --input-xgmml xgmml" if (not $inputBlast or not -f $inputBlast) and (not $inputXgmml or not -f $inputXgmml);
die "Need --output-map" if not $output;

$includeMeta = defined($includeMeta);

my $filterIds = {};
if ($cdhit) {
    $cdhit = "" if not -f $cdhit;
    $filterIds = getCdHitClusters($cdhit) if $cdhit;
}



my %degree;
my %N;
my $in;

my $parseFn = sub {};
if ($inputBlast) {
    open $in, "<", $inputBlast;
    $parseFn = sub {
        my ($source, $target) = split(m/\t/, $_[0]);
        if (not $cdhit or ($filterIds->{$source} and $filterIds->{$target})) {
            return ($source, $target);
        } else {
            return ("", "");
        }
    };
} else {
    open $in, "<", $inputXgmml;
    $parseFn = sub {
        my $line = $_[0];
        return ("", "") if not $line =~ m/\<edge/;
        my ($source, $target);
        if ($line =~ m/label="([^"]+),([^"]+)"/) {
            $source = $1;
            $target = $2;
        } else {
            ($source = $line) =~ s/^.*source="([^"]+)".*$/$1/s;
            ($target = $line) =~ s/^.*target="([^"]+)".*$/$1/s;
        }
        return ($source, $target);
    };
}

while (my $line = <$in>) {
    my ($source, $target) = &$parseFn($line);
    next if not $source;
    $degree{$source}++;
    $degree{$target}++;
    push @{$N{$source}}, $target;
    push @{$N{$target}}, $source;
}

close $in;

map { if (not exists $degree{$_}) { $degree{$_} = 0; $N{$_} = []; } } keys %$filterIds;


my $NC = getConnectivity(\%degree, \%N);

open my $out, ">", $output;

if ($includeMeta and $NC->{_meta}) {
    $out->print("_META\tmin\t$NC->{_meta}->{min}\tmax\t$NC->{_meta}->{max}\n");
}

$out->print(join("\t", "ID", "NC", "COLOR"), "\n");
foreach my $id (sort keys %$NC) {
    next if $id eq "_meta";
    $out->print(join("\t", $id, $NC->{$id}->{nc}, $NC->{$id}->{color}), "\n");
}

close $out;



sub getCdHitClusters {
    my $file = shift;
    my $cp = new CdHitParser();
    open my $fh, "<", $file;
    while (my $line = <$fh>) {
        chomp $line;
        $cp->parse_line($line);
    }
    $cp->finish;
    my $data = {};
    map { $data->{$_} = 1 } $cp->get_clusters();
    return $data;
}


