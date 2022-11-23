#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/lib";
use AlignmentScore;


my ($inputBlast, $outputBlast, $filter, $minLen, $maxLen, $minVal, $inputFasta, $outputFasta, $domainLenMeta, $idListFile);
my $result = GetOptions(
    "blastin=s"         => \$inputBlast,
    "blastout=s"        => \$outputBlast,
    "filter=s"          => \$filter,
    "minlen=s"          => \$minLen,
    "maxlen=s"          => \$maxLen,
    "minval=s"          => \$minVal,
    "fastain=s"         => \$inputFasta,
    "fastaout=s"        => \$outputFasta,
    "domain-meta=s"     => \$domainLenMeta,
    "filter-id-list=s"  => \$idListFile,
);

my %sequences;

my ($filterEvalue, $filterBitscore, $filterPid) = (0, 0, 0);

$minLen = 0 if not defined $minLen;
$maxLen = 0 if not defined $maxLen;



if (not $filter) {
    die "you must specify the filter parameter";
}
if (not defined $minVal) {
    die "you must specify a minimum value to filter that is >= zero";
}
if (not $outputBlast) {
    die "you must specify an output file with -out";
}
if (not $inputBlast) {
    die "you must specify an input blast file with -blast";
}



if ($filter =~ /^eval$/) {
    $filterEvalue = 1;
} elsif ($filter =~ /^bit$/) {
    $filterBitscore = 1;
} elsif ($filter =~ /^pid$/) {
    $filterPid = 1;
}

if (not $filterEvalue and not $filterBitscore and not $filterPid) {
    die "you must specify a filter of either: eval, bit, or pid";
}


my $idList = {};
if ($idListFile) {
    $idList = getIdsFromFile($idListFile);
}



open BLAST, $inputBlast or die "cannot open blast output file $inputBlast";
open OUT, ">$outputBlast" or die "cannot write to output file $outputBlast";

while (my $line = <BLAST>) {
    my $origline = $line;
    chomp $line;
    
    my @parts = split /\t/, $line;
    #   0     1     2     3      4          5      6
    my ($qid, $sid, $pid, $alen, $bitscore, $qlen, $slen) = @parts;

    # Exclude if taxonomy filtering is in effect and one or other of the blast results is filtered out
    next if ($idListFile and (not $idList->{$qid} or not $idList->{$sid}));

    if ($filterEvalue) {
        my $alignmentScore = compute_ascore(@parts);
        if ($alignmentScore >= $minVal and $qlen >= $minLen and $slen >= $minLen and (($qlen <= $maxLen and $slen <= $maxLen) or $maxLen == 0)) {
            print OUT "$origline";
        } elsif ($alignmentScore < $minVal) {
            last;
        }
    } elsif ($filterBitscore) {
        if ($bitscore >= $minVal and $qlen >= $minLen and $slen >= $minLen and (($qlen <= $maxLen and $qlen <= $maxLen) or $maxLen == 0)) {
            print OUT "$origline";
        } elsif ($pid < $minVal) {
            last;
        }
    } elsif ($filterPid) {
        if ($pid >= $minVal and $qlen >= $minLen and $slen >= $minLen and (($qlen <= $maxLen and $slen <= $maxLen) or $maxLen == 0)) {
            print OUT "$origline";
        }
    }
}

close OUT;
close BLAST;


open FASTAIN, $inputFasta or die "Cannot open fasta file $inputFasta";
open FASTAOUT, ">$outputFasta" or die "Cannot write to fasta file $outputFasta";
my $sequence = "";
my @seqLines; # keep track of individual lines in the sequence since we write them out as they come in
my $key = "";
my %lenMap;
while (my $line = <FASTAIN>) {
    chomp $line;
    if ($line =~ /^>/) {
        if ($key and length $sequence >= $minLen and (length $sequence <= $maxLen or $maxLen == 0)) { 
            print FASTAOUT "$key\n", join("\n", @seqLines), "\n\n";
            $key =~ s/^\>(.+?):\d+:\d+$/$1/;
            $lenMap{$key} = length $sequence;
        }
        (my $upId = $line) =~ s/^>([A-Z0-9]+).*$/$1/;
        $key = (not $idListFile or $idList->{$upId}) ? $line : "";
        $sequence = "";
        @seqLines = ();
    } elsif ($key) {
        $sequence .= $line;
        push @seqLines, $line;
    }
}
print FASTAOUT "$key\n", join("\n", @seqLines), "\n\n" if $key;
close FASTAOUT;
close FASTAIN;


if ($domainLenMeta) {
    my $field = "Cluster_ID_Domain_Length";
    open META, ">>", $domainLenMeta;
    foreach my $id (keys %lenMap) {
        print META "$id\n\t$field\t$lenMap{$id}\n";
    }
    close META;
}




sub getIdsFromFile {
    my $idListFile = shift;

    my %idList;

    open my $fh, "<", $idListFile or die "Unable to open id list file $idListFile: $!";
    while (<$fh>) {
        chomp;
        next if m/^\s*$/;
        $idList{$_} = 1;
    }
    close $fh;

    return \%idList;
}



