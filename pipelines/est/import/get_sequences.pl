#!/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use FindBin;
use Time::HiRes;

use lib "$FindBin::Bin/lib";

use EFI::Import::Config::Sequences;
use EFI::Import::SequenceDB;
use EFI::Import::Logger;




my $logger = new EFI::Import::Logger();

my $config = new EFI::Import::Config::Sequences();
my ($err) = $config->validateAndProcessOptions();

if ($config->wantHelp()) {
    $config->printHelp($0);
    exit(0);
}

if (@$err) {
    $logger->error(@$err);
    $config->printHelp($0);
    die "\n";
}


my $seqDb = new EFI::Import::SequenceDB(config => $config);

# Populates the sequence structure with sequences from the sequence database
my $inputIdsFile = $config->getConfigValue("sequence_ids_file");
my $outputFile = $config->getConfigValue("output_sequence_file");

my $_start = time();

$logger->message("Retrieving the sequences from the IDs in $inputIdsFile from " . $config->getFastaDb());
my $numIds = $seqDb->getSequences($inputIdsFile, $outputFile);

my $_elapsed = int((time() - $_start) * 1000);

$logger->message("Found $numIds IDs in FASTA file in $_elapsed ms"); 

#TODO: handle user-specified FASTA sequences (e.g. Option C)



