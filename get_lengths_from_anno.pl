#!/usr/bin/env perl

# This script reads the annotation file (struct.out) and outputs a file containing data
# for a length histograph for ALL sequences, not just UniRef seed sequences.

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}


use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/lib";

use FileUtil;
use EFI::Database;



my ($annoFile, $lengthFile, $configFile, $incfrac);
my $result = GetOptions(
    "struct=s"      => \$annoFile,
    "lengths=s"     => \$lengthFile, # Output
    "config=s"      => \$configFile,
    "incfrac=f"     => \$incfrac,
);


die "Requires input -struct argument for annotation IDs" if not $annoFile or not -f $annoFile;
die "Requires output -lengths argument for length file" if not $lengthFile;


if (not defined $configFile or not -f $configFile) {
    if (exists $ENV{EFI_CONFIG}) {
        $configFile = $ENV{EFI_CONFIG};
    } else {
        die "--config file parameter is not specified";
    }
}

$incfrac = 0.99 if not defined $incfrac or $incfrac !~ m/^[\.\d]+$/;


my $db = new EFI::Database(config_file_path => $configFile);
my $dbh = $db->getHandle();


# Contains the attributes for each UniRef cluster ID
my $annoMap = FileUtil::read_struct_file($annoFile);

my @uniprotIds;
foreach my $clId (keys %$annoMap) {
    my $ids = exists $annoMap->{$clId}->{UniRef90_IDs} ? $annoMap->{$clId}->{UniRef90_IDs} :
              exists $annoMap->{$clId}->{UniRef50_IDs} ? $annoMap->{$clId}->{UniRef50_IDs} : "";
    my @ids = split(m/,/, $ids);
    push @uniprotIds, @ids;
}


my $numSequences = 0;
my @lengths;
while (@uniprotIds) {
    my @batch = splice(@uniprotIds, 0, 50);
    my $queryIds = join("','", @batch);
    my $sql = "SELECT accession, Sequence_Length FROM annotations WHERE accession IN ('$queryIds')";
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    while (my $row = $sth->fetchrow_arrayref) {
        my $len = $row->[1];
        $lengths[$len] = 0 if not defined $lengths[$len];
        $lengths[$len]++;
        $numSequences++;
    }
}


my $endTrim = $numSequences * (1 - $incfrac) / 2;
$endTrim = int $endTrim;

my ($sequenceSum, $minCount, $count) = (0, 0, 0);
foreach my $len (@lengths) {
    if ($sequenceSum <= ($numSequences - $endTrim)) {
        $count++;
        $sequenceSum += $len if defined $len;
        if ($sequenceSum < $endTrim) {
            $minCount++;
        }
    }
}


open OUT, ">", $lengthFile or die "Unable to open length file $lengthFile for writing: $!";

for (my $i = $minCount; $i <= $count; $i++) {
    if (defined $lengths[$i]) {
        print OUT "$i\t$lengths[$i]\n";
    } else {
        print OUT "$i\t0\n";
    }
}

close OUT;


