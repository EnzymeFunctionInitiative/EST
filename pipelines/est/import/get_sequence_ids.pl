#!/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use FindBin;
use Time::HiRes;

use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../../../lib";

use EFI::Database;
use EFI::Import::Config::IdList;
use EFI::Import::Sources;
use EFI::Import::Filter;
use EFI::Import::Writer;
use EFI::Import::Sunburst;
use EFI::Import::Statistics;
use EFI::Import::Logger;




my $logger = new EFI::Import::Logger();

my $config = new EFI::Import::Config::IdList();
my ($err) = $config->validateAndProcessOptions();

if ($config->wantHelp()) {
    $config->printHelp($0);
    exit(0);
}

if (@$err) {
    #$logger->error(@$err);
    $config->printHelp($0, $err);
    die "\n";
}


my $sunburst = new EFI::Import::Sunburst();
my $stats = new EFI::Import::Statistics(config => $config);
my $efiDbName = $config->getConfigValue("efi_db");
my $efiDb = new EFI::Database(config => $config->getEfiDatabaseConfig(), db_name => $efiDbName);

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
$logger->message("Retrieving accession IDs from source $efiDbName");
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








__END__

=head1 get_sequence_ids.pl

=head2 NAME

get_sequence_ids.pl - retrieve sequence IDs from a database or file and save them for
use by a script later in the EST import pipeline

=head2 SYNOPSIS

    # BLAST import option; init_blast.out is obtained from a BLAST; see below
    get_sequence_ids.pl --mode blast --blast-output init_blast.out --blast-query <QUERY_FILE> --efi-config <EFI_CONFIG_FILE> --efi-db <EFI_DB_FILE>

    # Family import option
    get_sequence_ids.pl --mode family --efi-config <EFI_CONFIG_FILE> --efi-db <EFI_DB_FILE>

    # Accession import option
    get_sequence_ids.pl --mode accession --accessions <USER_ACC_FILE> --efi-config <EFI_CONFIG_FILE> --efi-db <EFI_DB_FILE>

    # Accession import option
    get_sequence_ids.pl --mode fasta --fasta <USER_FASTA_FILE> --efi-config <EFI_CONFIG_FILE> --efi-db <EFI_DB_FILE>

=head2 DESCRIPTION

This script retrieves sequence IDs from a database or file and saves them for use by a script later in the EST import pipeline.
There are four EST import modes available: BLAST, Family, Accessions, and FASTA.  
See C<import_fasta.pl> for extra functionality required to complete the FASTA import option.
In addition to outputting a file containing sequence identifiers, a metadata file is output that contains basic information about the sequences (e.g. how they were obtained).

=head2 MODES

=head3 B<BLAST>

The BLAST import option takes output from a BLAST and retrieves the IDs.  For example,
the BLAST step might look like this:

    # First, sequences are obtained via a BLAST
    #blastall -p blastp -i <QUERY_FILE> -d <BLAST_IMPORT_DB> -m 8 -e <BLAST_EVALUE> -b <BLAST_NUM_MATCHES> -o init_blast.out
    #awk '! /^#/ {print \$2"\t"\$11}' init_blast.out | sort -k2nr > blast_hits.tab

C<QUERY_FILE> is the path to the file that contains the user-specified query.
C<BLAST_IMPORT_DB> is the path to a BLAST-formatted database.
C<BLAST_EVALUE> and <BLAST_NUM_MATCHES> are the e-value to use and the maximum number of matches to return from the BLAST, respectively.
The process generates a C<blast_hits.tab> file.  Assuming the process completed successfully, the next step is
to run this script.  An additional output from the script is the C<blast_hits.tab> file, which is used
during SSN generation for the BLAST import option only.

=head4 Example Usage

    get_sequence_ids.pl --mode blast --blast-output init_blast.out --blast-query <QUERY_FILE> --efi-config <EFI_CONFIG_FILE> --efi-db <EFI_DB_FILE>

=head4 Parameters

=over

=item C<--blast-output>

The file from the BLAST to parse.

=item C<--blast-query>

The file that contains the user FASTA query sequence.

=back

=head3 B<Family>

The Family import option uses one or more protein families to retrieve a list of IDs. The families that
are supported are Pfam, InterPro, Pfam clans, SSF, and GENE3D.

=head4 Example Usage

    get_sequence_ids.pl --mode family --family PF05544,IPR007197
    get_sequence_ids.pl --mode family --family PF05544 --family IPR007197

=head4 Parameters

=over

=item C<--family>

Specify one or more families by using multiple C<--family> arguments, or a single C<--family> argument
with one or more families separated by commas.  Families are specified using the following formats:
B<Pfam>: C<PF#####>, B<InterPro>: C<IPR######>, B<Pfam clans>: C<CL####>, B<SSF>: C<SSF#####>, and
B<GENE3D>: C<G3DSA...>.

=back

=head3 B<Accession>

The Accession import option loads sequence IDs from a user-specified file.  The file is parsed to
identify UniProt sequence IDs, and if non-UniProt IDs are detected, attempts to map those back to
UniProt IDs.  The result is a file with only UniProt IDs.

=head4 Example Usage

    get_sequence_ids.pl --mode accession --accessions <USER_ACC_FILE>

=head4 Parameters

=over

=item C<--accessions>

A path to a file containing sequence IDs.  Each identifier should be on a separate line.

=back

=head3 B<FASTA>

The FASTA import option parses sequence IDs from FASTA headers in a user-specified FASTA file.
The headers are parsed to identify UniProt sequence IDs, and if non-UniProt IDs are detected, attempts to map those back to UniProt IDs.
The result is an accession ID list file with only UniProt IDs.
Additionally, if sequences could not be identified as UniProt or mapped to UniProt, anonymous sequence IDs are assigned that begin with the letters C<ZZ>.

=head4 Example Usage

    get_sequence_ids.pl --mode fasta --fasta <USER_FASTA_FILE>

=head4 Parameters

=over

=item C<--fasta>

A path to a file containing FASTA sequences.  Identifiers are pulled from the sequence headers in the file.

=item C<--seq-mapping-file> (optional, defaults)

This file is necessary to map UniProt or anonymous identifiers to the proper header line in the input FASTA file.
The file is provided to the B<C<import_fasta.pl>> script which reformats the user FASTA file into an acceptable format with proper header IDs.
If this is not specified, the file is named according to the C<seq_mapping> value in the B<C<EFI::Import::Config::Defaults>> module and put in the output directory.

=back



=head3 Shared Arguments

The import options share a number of arguments.

=over

=item C<--sequence-ids-file> (optional, defaults)

The output file that the IDs from the sequence ID retrieval are stored in.
If this is not specified, the file is named according to the C<accession_ids> value
in the B<C<EFI::Import::Config::Defaults>> module and put in the output directory.

=item C<--mode> (required)

Specifies the mode; supported values are C<blast>, C<family>, and C<accession>.

=item C<--efi-config> (required)

The path to the config file used for the database.

=item C<--efi-db> (required)

The path to the SQLite database file or the name of a MySQL/MariaDB database.  The database connection
parameters are specified in the C<--efi-config> file.

=item C<--sequence-version> (optional, defaults)

UniProt, UniRef90, and UniRef50 sequences can be retrieved.  Acceptable values are C<uniprot> (default),
C<uniref90>, and C<uniref50>.  When this version is C<unirefXX>, the sequences retrieved from the
BLAST and Family import options are UniRefXX sequences only.  When the import option is Accession,
all sequences in the import file are used, including ones that are not UniRefXX.

=item C<--output-dir> (optional, defaults)

This is the directory to store files in if they are not specified as arguments.  If it is not
specified, the current working directory is used.

=item C<--output-metadata-file> (optional, defaults)

The script also outputs a metadata file (see B<C<EFI::EST::Metadata>> for the format of this file).
If this is not specified, the file is named according to the C<sequence_metadata> value
in the B<C<EFI::Import::Config::Defaults>> module and put in the output directory.

=item C<--output-sunburst-ids-file-> (optional, defaults)

The EST graphical tools support the display of taxonomy in the form of sunburst diagrams.
If this is not specified, the file is named according to the C<sunburst_ids> value
in the B<C<EFI::Import::Config::Defaults>> module and put in the output directory.

=item C<--output-stats-file> (optional, defaults)

Statistics are computed for the sequences that are retrieved (e.g. size of family,
number of sequences).
If this is not specified, the file is named according to the C<import_stats> value
in the B<C<EFI::Import::Config::Defaults>> module and put in the output directory.

=back


