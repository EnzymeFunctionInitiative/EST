#!/usr/bin/env perl

use Getopt::Long;
use strict;

my ($runDir, $out);
my $result = GetOptions(
    "run-dir=s"     => \$runDir,
    "out=s"         => \$out,
);



open(OUT, ">$out") or die "cannot write to $out\n";
print OUT "File\t\t\tNodes\tEdges\tSize\n";

my $fullFile = glob("$runDir/*full_ssn*");
print OUT saveFile($fullFile, 1);

foreach my $filePath (sort {$b cmp $a} glob("$runDir/*")){
    if ($filePath =~ /\.xgmml$/) {
        if (-s $filePath) {
            if ($filePath !~ /_full_ssn\.xgmml/) {
                print OUT saveFile($filePath, 0);
            }
        } else {
            (my $filename = $filePath) =~ s%^.*/([^/]+)$%$1%;
            print OUT "$filename\t0\t0\t0\n";
        }
    }
}

close DIR;

system("touch $out.completed");



sub saveFile {
    my ($filePath, $isFull) = @_;

#    my $filePath = "$tmpdir/$runDir/$filename";
#    $filePath = $filename if $filename =~ /full/;

    my $size = -s $filePath;
    my $nodes = `grep "^  <node" $filePath | wc -l`;
    my $edges = `grep "^  <edge" $filePath | wc -l`;
    chomp $nodes;
    chomp $edges;

    if ($edges == 0) {
        open FILE, $filePath;
        my $line = <FILE>;
        chomp $line;
        $line =~ s/^.*\((\d+)\).*$/$1/;
        $edges = ($line and $line !~ m/\D/) ? $line : 0;
        close FILE;
    }

    if ($nodes == 0) {
        $size = 0;
    }

    (my $filename = $filePath) =~ s%^.*/([^/]+)$%$1%;
    $filename .= "\t" if $isFull;

    return "$filename\t$nodes\t$edges\t$size\n"
}


