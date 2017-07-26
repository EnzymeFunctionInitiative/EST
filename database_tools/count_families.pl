#!/usr/bin/env perl

use strict;

use IO::Handle;
use Getopt::Long;

my $inputFile = "";
my $outputFile = "";
my $tableType = "";
my $append = undef;
my $mergeDomain = undef;
my $showProgress = undef;

my $result = GetOptions(
    "input=s"       => \$inputFile,
    "output=s"      => \$outputFile,
    "type=s"        => \$tableType,
    "append"        => \$append,
    "merge-domain"  => \$mergeDomain,
    "progress"      => \$showProgress,
);


my $usage = <<USAGE;
Usage: $0 -input input_tab_file -output output_count_tab_file -type type_column_value [-append] [-merge-domain]

Count the number of elements in the families in the input file.

    -input          path to the input tab file generated from formatdatfromxml.pl (e.g. PFAM, INTERPRO, ...)
    -output         path to the output tab file that stores the counts
    -type           the family type (e.g. INTERPRO, PFAM)
    -append         if present, the file is appended to instead of overwritten
    -merge-domain   if present, multiple occurences of the same accession ID in the same family are counted as one
USAGE
;


if (not -f $inputFile) {
    print "ERROR: -input input file parameter is required and must be a valid file.\n$usage\n";
    exit(1);
}

if (not $tableType) {
    print "ERROR: -type input table type parameter is required.\n$usage\n";
    exit(1);
}

$mergeDomain = defined $mergeDomain ? 1 : 0;
$showProgress = defined $showProgress ? 1 : 0;

my %counts;
my %merges;

open INPUT, $inputFile or die "Unable to open the input file '$inputFile': $!";

my $size = -s $inputFile;
my $progress = 0;

while (<INPUT>) {
    chomp;
    my ($family, $accId, $startDomain, $endDomain) = split(m/\t/);
    if (exists $counts{$family}) {
        if (not $mergeDomain or not exists $merges{"$family-$accId"}) {
            $counts{$family}++;
            $merges{"$family-$accId"} = 1;
        }
    } else {
        $counts{$family} = 1;
    }

    if ($showProgress) {
        my $posPct = int(tell(INPUT) * 100 / $size);
        if ($posPct > $progress) {
            $progress = $posPct;
            print "\rReading input file progress: $progress%";
            select()->flush();
        }
    }
}

print "\n" if $showProgress;

close INPUT;


$append = defined $append ? ">>" : ">";
open OUTPUT, "$append $outputFile" or die "Unable to open the output file '$outputFile' for writing ($append): $!";

my @families = sort keys %counts;
my $c = 0;
my $progress = 0;
foreach my $family (@families) {
    print OUTPUT join("\t", $tableType, $family, $counts{$family}), "\n";

    if ($showProgress) {
        my $pos = int($c++ * 100 / ($#families + 1));
        if ($pos > $progress) {
            $progress = $pos;
            print "\rWriting output file progress: $progress%";
            select()->flush();
        }
    }
}

print "\n" if $showProgress;

close OUTPUT;


