#!/usr/bin/env perl

use strict;

use List::MoreUtils qw(uniq);
use IO::Handle;
use Getopt::Long;

my $inputFile = "";
my $outputFile = "";
my $tableType = "";
my $clanFile = "";
my $unirefFile = "";
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
    "uniref=s"      => \$unirefFile,
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
    -uniref         if present, the file is parsed for UniRef seed sequences and those are output with the
                    families as separate fields.

The output format is as follows:

FAMILY  FULL_COUNT  UNIREF50_COUNT  UNIREF90_COUNT

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

my (%unirefData, %ur50Sizes, %ur90Sizes, %ur50ClanSizes, %ur90ClanSizes);
if (-f $unirefFile) {
    getUnirefData($unirefFile, \%unirefData);
}


open INPUT, $inputFile or die "Unable to open the input file '$inputFile': $!";

my $size = -s $inputFile;
my $progress = 0;

while (<INPUT>) {
    chomp;
    my ($family, $accId, $startDomain, $endDomain) = split(m/\t/);
    if (exists $counts{$family}) {
        print "$family $accId $startDomain $endDomain $counts{$family} 1" if ($family eq "IPR000015");
        if (not $mergeDomain or not exists $merges{"$family-$accId"}) {
            $counts{$family}++;
            $merges{"$family-$accId"} = 1;
            print "  2" if ($family eq "IPR000015");
        }
        print "\n" if ($family eq "IPR000015");
    } else {
        print "$family $counts{$family} 0\n" if ($family eq "IPR000015");
        $counts{$family} = 0;
    }

    if ($unirefFile and exists $unirefData{$accId}) {
        $ur50Sizes{$family}->{ $unirefData{$accId}->{ur50} } = 1;
        $ur90Sizes{$family}->{ $unirefData{$accId}->{ur90} } = 1;
    }

    if (exists $famToClan{$family}) {
        my $clan = $famToClan{$family};
        push @{ $clanData{$clan}->{ids} }, $accId;
        if ($unirefFile and exists $unirefData{$accId}) {
            $ur50ClanSizes{$clan}->{ $unirefData{$accId}->{ur50} } = 1;
            $ur90ClanSizes{$clan}->{ $unirefData{$accId}->{ur90} } = 1;
        }
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
print join("\t", "Type", "Family", "TotalSize", "UniRef50Size", "UniRef90Size"), "\n"; #deliberately to stdout

my @families = sort keys %counts;
my $c = 0;
my $progress = 0;
foreach my $family (@families) {
    my @outCounts = ($counts{$family});
    push @outCounts, scalar(keys(%{ $ur50Sizes{$family} })) if exists $ur50Sizes{$family};
    push @outCounts, scalar(keys(%{ $ur90Sizes{$family} })) if exists $ur90Sizes{$family};
    print OUTPUT join("\t", $tableType, $family, @outCounts), "\n";

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
    my @outCounts = scalar @ids;
    push @outCounts, scalar(keys(%{ $ur50ClanSizes{$clan} })) if exists $ur50ClanSizes{$clan};
    push @outCounts, scalar(keys(%{ $ur90ClanSizes{$clan} })) if exists $ur90ClanSizes{$clan};
    #my @fams = @{ $clanData{$clan}->{fams} };
    print OUTPUT join("\t", "CLAN", $clan, @outCounts), "\n";
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



sub getUnirefData {
    my $file = shift;
    my $data = shift;

    open UR, $file or die "Unable to open UniRef file $file: $!";

    while (<UR>) {
        chomp;
        my ($id, $ur50, $ur90) = split /\t/;

        $data->{$id} = {ur50 => $ur50, ur90 => $ur90};
    }

    close UR;
}


