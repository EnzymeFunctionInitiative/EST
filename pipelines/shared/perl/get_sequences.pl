
use strict;
use warnings;

use Data::Dumper;
use FindBin;
use Time::HiRes;

use lib "$FindBin::Bin/../../../lib";

use EFI::Import::Config::Sequences;
use EFI::Import::SequenceDB;
use EFI::Import::Logger;




my $logger = new EFI::Import::Logger();

my $optionParser = new EFI::Import::Config::Sequences();
my ($status, $help) = $optionParser->validateOptions();

if ($help) {
    print "$help\n";
    exit(not $status); # if error, status is 0, so exit non zero to indicate to shell that there was a problem
}

my $config = $optionParser->getOptions();




my $seqDb = new EFI::Import::SequenceDB(fasta_db => $config->{fasta_db});

# Populates the sequence structure with sequences from the sequence database
my $inputIdsFile = $config->{sequence_ids_file};
my $outputFile = $config->{output_sequence_file};

my $_start = time();

$logger->message("Retrieving the sequences from the IDs in $inputIdsFile from " . $config->{fasta_db});
my $numIds = $seqDb->getSequences($inputIdsFile, $outputFile);

my $_elapsed = int((time() - $_start) * 1000);

if ($numIds == -1) {
    $logger->message("Error retrieving FASTA sequences; unable to find BLAST programs");
    exit(1);
}

$logger->message("Found $numIds IDs in FASTA file in $_elapsed ms"); 








__END__

=head1 get_sequences.pl

=head2 NAME

get_sequences.pl - retrieve the FASTA sequences for each ID in a file with UniProt accession IDs

=head2 SYNOPSIS

    get_sequences.pl --fasta-db <BLAST_DATABASE> --sequence-ids-file accession_ids.txt --output-sequence-file all_sequences.fasta

=head2 DESCRIPTION

B<get_sequences.pl> retrieves sequences from a BLAST-formatted database.  The sequences that are retrieved
are specified in an input file provided on the command line.

=head3 Arguments

=over

=item C<--fasta-db>

The path to a BLAST-formatted database that was built using a set of FASTA sequences.

=item C<--output-dir> (optional, defaults)

The directory to read and write the input and output files from and to. Defaults to the
current working directory if not specified.

=item C<--sequence-ids-file> (optional, defaults)

The path to the input file containing a list of sequence IDs.
If this is not specified, the file with the name corresponding to the C<accession_ids> value
in the B<EFI::Import::Config::Defaults> module is used from the output directory.

=item C<--output-sequence-file> (optional, defaults)

The path to the output file containing all of the FASTA sequences that were retrieved from the database.
If this is not specified, the file with the name corresponding to the C<all_sequences> value
in the B<EFI::Import::Config::Defaults> module is used in the output directory.

=back

