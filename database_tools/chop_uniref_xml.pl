#!/usr/bin/env perl

use Getopt::Long;
use strict;

my ($inFile, $outDir, $debugIter, $batchSize) = ("", "", 2**50, 200000);

my $result = GetOptions(
    "in=s"          => \$inFile,
    "outdir=s"      => \$outDir,
    "debug-iter=i"  => \$debugIter,
    "batch-size=i"  => \$batchSize,
);

die "Invalid arguments" if not defined $inFile or not -f $inFile or not $outDir or not -d $outDir;


open XML, $inFile or die "could not open XML file '$inFile' for fragmentation\n";

my $head = "";
my $tail = "";

my $line = "";
while ($line = <XML>) {
    if ($line =~ /<entry/) {
        last;
    } else {
        if ($line =~ /<(UniRef\d+) /) {
            $tail = "</" . $1 . ">\n";
        }
        $head .= $line;
    }
}

# Override because of the extra stuff that is put into the first tag.
$head = <<HEAD;
<?xml version="1.0" encoding="ISO-8859-1" ?>
<uniref>
HEAD
$tail = "</uniref>";

my $entryCount = 0;
my $file = 0;

open OUT, ">$outDir/$file.xml" or die "Could not create xml fragment $outDir/$file.xml";
print OUT $head;

while (defined $line) {
    if ($line =~ /<entry/) {
        if ($entryCount + 1 > $debugIter) {
            print OUT $tail;
            last;
        }
        if (($entryCount++ % $batchSize) == 0) {
            print OUT $tail;
            close OUT;
            open OUT, ">$outDir/$file.xml" or die "Could not create xml fragment $outDir/$file.xml";
            print OUT $head;
#            $entryCount = 0;
            $file++;
        }
    }
    print OUT $line if $line !~ m/^<\/uniref/i;
    $line = <XML>;
}

print OUT $tail;
close OUT;

close XML;

