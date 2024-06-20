#!/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use FindBin;
use Time::HiRes;

use lib "$FindBin::Bin/lib";

use EFI::Database;
use EFI::Import::Config;
use EFI::Import::Sources;
use EFI::Import::Filter;
use EFI::Import::Writer;
use EFI::Import::Sunburst;
use EFI::Import::Statistics;
use EFI::Import::Logger;




my $logger = new EFI::Import::Logger();

my $config = new EFI::Import::Config();
my @err = $config->validateAndProcessOptions();
if (@err) {
    $logger->error(@err);
    die "\n";
}


my $sunburst = new EFI::Import::Sunburst();
my $stats = new EFI::Import::Statistics(config => $config);
my $efiDb = new EFI::Database(config => $config->getEfiDatabaseConfig());

my $sources = new EFI::Import::Sources(config => $config, efi_db => $efiDb, sunburst => $sunburst, stats => $stats);
my $filter = new EFI::Import::Filter(config => $config, efi_db => $efiDb, logger => $logger);
my $writer = new EFI::Import::Writer(config => $config, sunburst => $sunburst, stats => $stats);

my $source = $sources->createSource();
if (not $source) {
    $logger->error($sources->getErrors());
    die "\n";
}
$logger->message("Using " . $source->getType() . " as source");

# Retrieve only the IDs from the input sequence family or file
$logger->message("Retrieving accession IDs from source");
my $_start = time();

my $seqData = $source->getSequenceIds();
if (not $seqData) {
    $logger->error($source->getErrors());
    die "\n";
}
my $numIds = $stats->getValue("num_ids");

my $_elapsed = int((time() - $_start) * 1000);
$logger->message("Found $numIds UniProt sequence IDs in $_elapsed ms");

# Input is a hashref in the structure below; the method updates the structure rather than creating a new one
$logger->message("Applying filters");
my $numRemoved = $filter->filterIds($seqData);
$logger->message("Applied filters and removed a total of $numRemoved IDs");

# Saves to metadata file
$logger->message("Saving sequence IDs and metadata to the files");
$writer->saveSequenceIdData($seqData);












# MODES
# 1. Get sequences from BLAST job IDs
# 2. Get sequences from a family
# 3. Get sequences from a FASTA file
# 4. Get sequences from IDs in an accession file
#
# FILTERING
# 1. BLAST
#    a. DB type: select sequence database before running and filtering. Options include UniRef/UniProt and Fragments/No-Fragments
#    b. Taxonomy
# 2. Family
#    a. Fragment
#    b. Taxonomy
#    c. Fraction
#    d. Domain
# 3. FASTA
#    a. Fragment
#    b. Taxonomy
#    c. Restrict to specified family(s)
#    d. Include specified family(s)
# 4. Accession (input can be UniRef)
#    a. Fragment
#    b. Taxonomy
#    c. Restrict to specified family(s)
#    d. Include specified family(s)
#
# Once a list of sequences is obtained, the sequences are retrieved from the BLAST database, and a metadata file is
# created that contains the sequence source.
#
#
#
#
#
#
# DB TYPE FILTERING FOR BLAST
# Before anything, select UniRef50, UniRef50-nf, UniRef90, UniRef90-nf, UniProt, UniProt-nf
#
#
# SEQUENCE RETRIEVAL
# 1. BLAST: after BLAST runs, extract sequences from file and retrieve from the selected database
# 2. Family: select from family ID-sequence ID table
#    a. If UniRef option is set join with UniRef mapping table
# 3. FASTA: parse IDs to look up metadata, and use sequences provided
# 4. Accession: look up metadata for IDs
#
#
# FRAGMENT FILTERING
# 1. BLAST: sequences are already filtered by using the appropriate database
# 2. Family: after IDs are retrieved, query DB metadata table to exclude fragment sequences
# 3. FASTA: after IDs are parsed, query DB metadata table to exclude fragment sequences
# 4. Accession: after IDs are parsed, query DB metadata table to exclude fragment sequences
#
#
# TAXONOMY FILTERING
#
#
#; if no-fragments option is used exclude by join on attributes table

