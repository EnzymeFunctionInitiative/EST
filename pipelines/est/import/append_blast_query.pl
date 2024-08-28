#!/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use Cwd;

use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../../../lib";

use EFI::Annotations::Fields qw(INPUT_SEQ_ID);
use EFI::Import::Config::Defaults;



my ($blastQueryFile, $outputSeqFile, $outputDir, $wantHelp);
my $result = GetOptions(
    "blast-query-file=s" => \$blastQueryFile,
    "output-sequence-file=s" => \$outputSeqFile,
    "output-dir=s" => \$outputDir,
    "help" => \$wantHelp,
);

$outputDir = getcwd() if not $outputDir;

checkArgs();



open my $queryFh, "<", $blastQueryFile or die "Unable to read blast query file $blastQueryFile: $!";
open my $outFh, ">>", $outputSeqFile or die "Unable to append to sequence file $outputSeqFile: $!";

$outFh->print(">" . &INPUT_SEQ_ID, "\n");
while (my $line = <$queryFh>) {
    next if $line =~ m/^>/;
    $outFh->print($line);
}

close $outFh;
close $queryFh;



sub checkArgs {
    printHelp() and exit(0) if $wantHelp;

    my $fail = 0;
    if (not $blastQueryFile or not -f $blastQueryFile) {
        print "Require --blast-query-file containing the FASTA sequence to use for the BLAST\n";
        $fail = 1;
    }
    if (not $outputSeqFile) {
        $outputSeqFile = get_default_path("all_sequences", $outputDir);
    }

    if ($fail) {
        printHelp();
        exit(1);
    }
}


sub printHelp {
    print <<HELP;
Usage: perl $0 --blast-query-file path_to_file
    [--output-sequence-file <path/to/output/sequences/file.fasta>]
    [--output-dir <path/to/output/dir>]

Description:
    Append the input BLAST query to the sequence import file

Options:
    --blast-query-file      file that contains the BLAST query sequence
    --output-sequence-file  file that contains the sequences already retrieved by the pipeline
    --output-dir            directory that contains the files for the job

HELP
    exit(0);
}








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

