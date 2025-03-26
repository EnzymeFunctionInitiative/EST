#!/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Annotations::Fields qw(:source);
use EFI::Import::Config::FastaImport;
use EFI::Import::Logger;
use EFI::Sequence::Collection;




my $logger = new EFI::Import::Logger();

my $optionParser = new EFI::Import::Config::FastaImport();
my ($status, $help) = $optionParser->validateOptions();

if ($help) {
    print "$help\n";
    exit(not $status); # if error, status is 0, so exit non zero to indicate to shell that there was a problem
}

my $config = $optionParser->getOptions();




my $lineMapping = loadMappingFile($config->{seq_mapping_file});

my $seqCollection = new EFI::Sequence::Collection();
$seqCollection->load($config->{sequence_meta_file});

my @seqIds = $seqCollection->getSequenceIds();

# filteredSeqIds is used to exclude any IDs/sequences in the FASTA file that were excluded due to
# filtering in a prior step.  fastaSource is used to determine if an ID in the input ID list
# (sequence metadata file) comes from the FASTA file; this is used to save IDs that originate only
# from a family that was added to a fasta import job.
my %filteredSeqIds;
my %fastaSource;
foreach my $id (@seqIds) {
    $filteredSeqIds{$id} = 1;
    my $source = $seqCollection->getSequence($id)->getAttribute(FIELD_SEQ_SRC_KEY) // "";
    $fastaSource{$id} = ($source eq FIELD_SEQ_SRC_VALUE_BOTH or $source eq FIELD_SEQ_SRC_VALUE_FASTA);
}


open my $in, "<", $config->{uploaded_fasta} or die "Unable to read input fasta file $config->{uploaded_fasta}: $!";
open my $out, ">", $config->{output_sequence_file} or die "Unable to write to output fasta file $config->{output_sequence_file}: $!";

my $lineNum = 0;
my $isValidSeq = 0;
while (my $line = <$in>) {
    if ($line =~ m/^>/) {
        # Check if the user-provided sequence header has a valid sequence that was parsed by the
        # pipeline, and if the mapped ID is included in the sequence metadata file (which is
        # created by the filter pipeline process to remove user-specified filters)
        my $mappedId = $lineMapping->{$lineNum};
        if ($mappedId) {
            # If true, then the ID passed the filtering in a prior step
            if ($filteredSeqIds{$mappedId}) {
                $out->print(">$lineMapping->{$lineNum}\n");
                $isValidSeq = 1;
            } else {
                #TODO: remove this debug
                print "REMOVED $mappedId FROM import fasta\n";
            }
        }
    } elsif ($line =~ m/^>/) {
        $isValidSeq = 0;
    } elsif ($isValidSeq) {
        # Print the current line from user-specified FASTA file
        $out->print($line);
    }
    $lineNum++;
}

close $out;
close $in;


open my $fh, ">", $config->{sequence_ids_file} or die "Unable to write to output sequence IDs file '$config->{sequence_ids_file}': $!";
map { $fh->print("$_\n") if not $fastaSource{$_}; } @seqIds;
close $fh;





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




__END__

=head1 import_fasta.pl

=head2 NAME

import_fasta.pl - import user-specified FASTA sequences into a form usable by the SSN creation pipeline instead of using C<get_sequences.pl>.

=head2 SYNOPSIS

    import_fasta.pl --uploaded-fasta-file <PATH/TO/FASTA_file>

=head2 DESCRIPTION

For all import methods but FASTA, the B<get_sequences.pl> script is used.  This script is
a replacement for that and is designed to work with FASTA sequences that do not have a
proper sequence ID.  It assigns anonymous sequence identifiers to the sequences and
writes them to the standard C<all_sequences> file that is outputted from C<get_sequences.pl>.

=head3 Arguments

=over

=item C<--uploaded-fasta-file> (required)

The path to the user-specified FASTA file.

=item C<--output-dir> (optional, defaults)

The directory to read and write the input and output files from and to. Defaults to the
current working directory if not specified.

=item C<--seq-mapping-file> (optional, defaults)

When C<get_sequence_ids.pl> is run in the FASTA mode, it outputs a file that maps
lines in the original user-specified FASTA file to anonymous sequence identifiers.
If this is not specified, the file with the name corresponding to the C<seq_mapping> value
in the B<EFI::Import::Config::Defaults> module is used in the output directory.

This file is a two column format file with a header line, where the first column
is the UniProt or anonymous ID and the second column is the line number where the
corresponding sequence header is located in the C<--user-uploaded-file> file.

=item C<--output-sequence-file> (optional, defaults)

The path to the output file containing all of the FASTA sequences that are reformatted
and renamed based on the C<--seq-mapping-file> file.
If this is not specified, the file with the name corresponding to the C<all_sequences> value
in the B<EFI::Import::Config::Defaults> module is used in the output directory.

=back

