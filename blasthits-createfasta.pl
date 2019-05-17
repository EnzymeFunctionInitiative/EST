#!/usr/bin/env perl

use strict;
use Getopt::Long;

die "EFIDBPATH environment variable must be present; did you forget to module load efiest?" if not exists $ENV{EFIDBPATH};


my ($fasta, $accessions, $countFile);
my $result = GetOptions(
    "fasta=s"           => \$fasta,
    "accessions=s"      => \$accessions,
    "seq-count-file=s"  => \$countFile,
);


die "Missing command line arguments" if not $fasta or not $accessions or not $countFile;


my $data_files = $ENV{EFIDBPATH};

print "using $data_files/combined.fasta as the Blast database\n";

open(FASTA, ">$fasta") or die "could not write to fasta file $fasta\n";
open(ACC, $accessions) or die "could not read accession file $accessions\n";

my $accCount = 0;

while(<ACC>){
    my $line=$_;
    chomp $line;
    my @sequences=split "\n", `fastacmd -d $data_files/combined.fasta -s $line`;
    foreach my $sequence (@sequences){
        $sequence=~s/^>\w\w\|(\w{6,10})\|.*/>$1/;
        print FASTA "$sequence\n";
    }
    $accCount++;
}

close ACC;
close FASTA;


open COUNT, ">$countFile";
print COUNT "Blast\t$accCount\n";
print COUNT "Total\t" . ($accCount + 1) . "\n";
close COUNT;


