#!/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/lib";

use EFI::Database;
use EFI::Import::Config;
use EFI::Import::SequenceDB;
use EFI::Import::SourceManager;
use EFI::Import::Filter;
use EFI::Import::Writer;
use EFI::Import::Sunburst;
use EFI::Import::Stats;

use constant FATAL => 1;
use constant WARNING => 2;



my $opt = getOptions();
my $config = getConfig($opt);
my @err = $config->validateAndProcessOptions();
if (@err) {
    handleErrors(FATAL, @err);
}


my $sunburst = new EFI::Import::Sunburst();
my $stats = new EFI::Import::Stats(config => $config);
my $efiDb = new EFI::Database(config => $config->getEfiDatabaseConfig());

my $typeMgr = new EFI::Import::SourceManager(config => $config, efi_db => $efiDb, sunburst => $sunburst, stats => $stats);
my $seqDb = new EFI::Import::SequenceDB(config => $config);
my $filter = new EFI::Import::Filter(config => $config, efi_db => $efiDb);
my $writer = new EFI::Import::Writer(config => $config, sunburst => $sunburst, stats => $stats);

my $getSeqHandler = $typeMgr->createSource();
if (not $getSeqHandler) {
    handleErrors(FATAL, $typeMgr->getErrors());
}

# Retrieve only the IDs from the input sequence family or file
my $seqData = $getSeqHandler->getSequenceIds();
if (not $seqData) {
    handleErrors(FATAL, $getSeqHandler->getErrors());
}

# Input is a hashref in the structure below; the method updates the structure rather than creating a new one
$filter->filterData($seqData);

# Populates the sequence structure with sequences from the sequence database
$seqDb->getSequences($seqData);

# Saves to fasta file and metadata file
$writer->saveData($seqData);






#
# seqData is a hash that looks like:
# {
#    type => uniprot|uniref50|uniref90,
#    ids => {
#        UNIPROT_ACC => [
#                {
#                    start => x, end => x
#                    # optionally, other things
#                }
#                # optionally other "pieces", e.g. for multi-domain proteins
#            ],
#        UNIPROT_ACC2 => ...
#    },
#    seq => {
#        UNIPROT_ACC => SEQ,
#        ...
#    },
#    meta => {
#        UNIPROT_ACC => {
#            source => x,
#            ...
#        },
#        ...
#    }
# }





sub handleErrors {
    my $status = shift;
    my @err = @_;
    my $msg = "Error";
    if (@err) {
        $msg = join("\n", @err);
    }
    if ($status == FATAL) {
        die "$msg\n";
    } else {
        warn "$msg\n";
    }
}


sub getConfig {
    my $opt = shift;
    my $config = new EFI::Import::Config(options => $opt);
    return $config;
}


sub getOptions {
    my $opt = EFI::Import::Config::getOptionDefaults();
    my @spec = EFI::Import::Config::getOptionSpec();
    GetOptions($opt, @spec);
    return $opt;
}



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
# created that contains the length of the sequence and the sequence source.
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

