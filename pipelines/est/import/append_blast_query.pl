#!/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use Cwd;

use lib "$FindBin::Bin/../../../lib";

use EFI::Annotations::Fields qw(INPUT_SEQ_ID);
use EFI::Import::Config::Defaults;
use EFI::Options;




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();


open my $queryFh, "<", $opts->{blast_query_file} or die "Unable to read blast query file $opts->{blast_query_file}: $!";
open my $outFh, ">>", $opts->{output_sequence_file} or die "Unable to append to sequence file $opts->{output_sequence_file}: $!";

$outFh->print(">" . &INPUT_SEQ_ID, "\n");
while (my $line = <$queryFh>) {
    next if $line =~ m/^>/;
    $outFh->print($line);
}

close $outFh;
close $queryFh;





sub validateAndProcessOptions {

    my $desc = "Append the input BLAST query to the sequence import file.";

    my $optParser = new EFI::Options(app_name => $0, desc => $desc);

    $optParser->addOption("blast-query-file=s", 1, "path to file containing the BLAST query sequence", OPT_FILE);
    $optParser->addOption("output-sequence-file=s", 0, "path to output sequence file that the input sequence gets appended to", OPT_FILE);
    $optParser->addOption("output-dir=s", 0, "path to directory containing input files for the EST job", OPT_FILE);

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    my $opts = $optParser->getOptions();

    $opts->{output_dir} = getcwd() if not $opts->{output_dir};
    if (not $opts->{output_sequence_file}) {
        $opts->{output_sequence_file} = get_default_path("all_sequences", $opts->{output_dir});
    }

    return $opts;
}




1;
__END__

=head1 append_blast_query.pl

=head2 NAME

append_blast_query.pl - append the input BLAST query to the sequence import file

=head2 SYNOPSIS

    # Read <FILE.fa> and append to <PATH/TO/all_sequences.fasta>
    append_blast_query.pl --blast-query-file <FILE.fa> --output-sequence-file <PATH/TO/all_sequences.fasta>
    
    # Read <FILE.fa> and append to <OUTPUT_DIR/all_sequences.fasta>
    append_blast_query.pl --blast-query-file <FILE.fa> --output-dir <OUTPUT_DIR>

    # Read <FILE.fa> and append to all_sequences.fasta in the current working directory
    append_blast_query.pl --blast-query-file <FILE.fa>

=head2 DESCRIPTION

BLAST import option for EST generates import sequences that are used for the all-by-all BLAST later in the
pipeline.  By default the query sequence (the sequence the user provided for the BLAST option)
is not included in the import sequences.  This script takes that query sequence and appends it to
the import sequence file.


=cut

