#!/usr/bin/env perl

use Getopt::Long;
use strict;

my ($run, $tmpdir, $out);
my $result = GetOptions(
    "run=s"	=> \$run,
    "tmp=s"	=> \$tmpdir,
    "out=s"	=> \$out,
);



open(OUT, ">$out") or die "cannot write to $out\n";
print OUT "File\t\t\tNodes\tEdges\tSize\n";

my $fullFile = glob("$tmpdir/$run/*full_ssn*");
print OUT saveFile($fullFile, 1);

foreach my $filePath (sort {$b cmp $a} glob("$tmpdir/$run/*")){
    if ($filePath =~ /\.xgmml$/) {
        if (-s $filePath) {
            if ($filePath !~ /full/) {
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

#    my $filePath = "$tmpdir/$run/$filename";
#    $filePath = $filename if $filename =~ /full/;

    my $size = -s $filePath;
    my $nodes = `grep "^  <node" $filePath | wc -l`;
    my $edges = `grep "^  <edge" $filePath | wc -l`;
    chomp $nodes;
    chomp $edges;

    (my $filename = $filePath) =~ s%^.*/([^/]+)$%$1%;
    $filename .= "\t" if $isFull;

    return "$filename\t$nodes\t$edges\t$size\n"
}


