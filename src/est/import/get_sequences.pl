#!/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use FindBin;
use Time::HiRes;

use lib "$FindBin::Bin/lib";

use EFI::Import::Config;
use EFI::Import::SequenceDB;
use EFI::Import::Logger;




my $logger = new EFI::Import::Logger();

my $config = new EFI::Import::Config(get_sequences => 1);
my @err = $config->validateAndProcessOptions();
if (@err) {
    $logger->error(@err);
    die "\n";
}


my $seqDb = new EFI::Import::SequenceDB(config => $config);

# Populates the sequence structure with sequences from the sequence database
my $inputIdsFile = $config->getConfigValue("id_file");
my $outputFile = $config->getConfigValue("seq_file");

my $_start = time();

$logger->message("Retrieving the sequences from the IDs in $inputIdsFile from " . $config->getFastaDb());
my $numIds = $seqDb->getSequences($inputIdsFile, $outputFile);

my $_elapsed = int((time() - $_start) * 1000);

$logger->message("Found $numIds IDs in FASTA file in $_elapsed ms"); 

#TODO: handle user-specified FASTA sequences (e.g. Option C)



