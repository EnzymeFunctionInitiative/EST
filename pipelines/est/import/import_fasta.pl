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


my $mappingFile = $config->getConfigValue("seq_mapping_file");
my $fastaFile = $config->getConfigValue("uploaded_fasta");
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




__END__

=head1 import_fasta.pl

=head2 NAME

import_fasta.pl - import user-specified FASTA sequences into a form usable by the SSN creation pipeline instead of using C<get_sequences.pl>.

=head2 SYNOPSIS

    import_fasta.pl --uploaded-fasta-file <PATH/TO/FASTA_file>

=head2 DESCRIPTION

For all import methods but FASTA, the C<get_sequences.pl> script is used.  This script is
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
in the B<C<EFI::Import::Config::Defaults>> module is used in the output directory.

This file is a two column format file with a header line, where the first column
is the UniProt or anonymous ID and the second column is the line number where the
corresponding sequence header is located in the C<--user-uploaded-file> file.

=item C<--output-sequence-file> (optional, defaults)

The path to the output file containing all of the FASTA sequences that are reformatted
and renamed based on the C<--seq-mapping-file> file.
If this is not specified, the file with the name corresponding to the C<all_sequences> value
in the B<C<EFI::Import::Config::Defaults>> module is used in the output directory.

=back

