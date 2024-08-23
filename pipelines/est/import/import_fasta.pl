#!/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../../../lib";

use EFI::Import::Config::FastaImport;
use EFI::Import::Logger;




my $logger = new EFI::Import::Logger();

my $config = new EFI::Import::Config::FastaImport();
my @err = $config->validateAndProcessOptions();
if (@err) {
    $logger->error(@err);
    die "\n";
}


my $mappingFile = $config->getConfigValue("seq_mapping_file");
my $fastaFile = $config->getConfigValue("uploaded_fasta_file");
my $outputFile = $config->getConfigValue("output_sequence_file");


my $lineMapping = loadMappingFile($mappingFile);

open my $in, "<", $fastaFile or die "Unable to read input fasta file $fastaFile: $!";
open my $out, ">", $outputFile or die "Unable to write to output fasta file $outputFile: $!";

my $lineNum = 0;
my $isValidSeq = 0;
while (my $line = <$in>) {
    if ($line =~ m/^>/ and $lineMapping->{$lineNum}) {
        $out->print(">$lineMapping->{$lineNum}\n");
        $isValidSeq = 1;
    } elsif ($line =~ m/^>/) {
        $isValidSeq = 0;
    } elsif ($isValidSeq) {
        $out->print($line);
    }
    $lineNum++;
}

close $out;
close $in;





sub loadMappingFile {
    my $file = shift;

    my $mapping = {};

    open my $fh, "<", $file or die "Unable to read mapping file $file: $!";

    my $headerLine = <$fh>;

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ m/^\s*$/ or $line =~ m/^#/;
        my ($id, $lineNum) = split(m/\t/, $line);
        $mapping->{$lineNum} = $id;
    }

    close $fh;

    return $mapping;
}


