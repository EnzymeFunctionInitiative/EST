#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/lib";
use AlignmentScore;


my ($minLen, $maxLen, $inputFasta, $outputFasta, $domainLenMeta, $idListFile);
my $result = GetOptions(
    "minlen=s"          => \$minLen,
    "maxlen=s"          => \$maxLen,
    "fastain=s"         => \$inputFasta,
    "fastaout=s"        => \$outputFasta,
    "domain-meta=s"     => \$domainLenMeta,
    "filter-id-list=s"  => \$idListFile,
);

$minLen = 0 if not defined $minLen;
$maxLen = 0 if not defined $maxLen;


my $idList = {};
if ($idListFile) {
    $idList = getIdsFromFile($idListFile);
}


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



