#!/usr/bin/env perl

use strict;

use List::MoreUtils qw(uniq);
use IO::Handle;
use Getopt::Long;

my $inputFile = "";
my $outputFile = "";
my $tableType = "";
my $clanFile = "";
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
    "clans=s"       => \$clanFile,
);


my $usage = <<USAGE;
Usage: $0 -input input_tab_file -output output_count_tab_file -type type_column_value [-append] [-merge-domain]

Count the number of elements in the families in the input file.

    -input          path to the input tab file generated from formatdatfromxml.pl (e.g. PFAM, INTERPRO, ...)
    -output         path to the output tab file that stores the counts
    -type           the family type (e.g. INTERPRO, PFAM)
    -append         if present, the file is appended to instead of overwritten
    -merge-domain   if present, multiple occurences of the same accession ID in the same family are counted as one
    -clans          if present and family type is PFAM, the clan sizes are also output
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



my %clanData;
my %famToClan;
if (-f $clanFile) {
    getClanData($clanFile, \%clanData, \%famToClan);
}


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

    if (exists $famToClan{$family}) {
        my $clan = $famToClan{$family};
        push @{ $clanData{$clan}->{ids} }, $accId;
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

print "\nWriting clan data\n";
foreach my $clan (sort keys %clanData) {
    my @allIds = @{ $clanData{$clan}->{ids} };
    my @ids = uniq @allIds;
    #my @fams = @{ $clanData{$clan}->{fams} };
    print OUTPUT join("\t", "CLAN", $clan, scalar(@ids)), "\n";
}



print "\n" if $showProgress;



close OUTPUT;









sub getClanData {
    my $clanFile = shift;
    my $clanData = shift;
    my $famToClan = shift;

    open CLANS, $clanFile or die "Unable to open $clanFile: $!";

    while (<CLANS>) {
        chomp;
        my ($fam, $clan, @stuff) = split /\t/;
        next if not $clan;
   
        $clanData->{$clan} = {fams => [], ids => [], ur50 => [], ur90 => []} if not exists $clanData->{$clan};
        push @{$clanData->{$clan}->{fams}}, $fam;
        $famToClan->{$fam} = $clan;
    }

    close CLANS;
}




