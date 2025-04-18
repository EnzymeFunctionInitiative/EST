append_blast_query
==================
Usage
-----

::

	Usage: perl pipelines/est/import/append_blast_query.pl --blast-query-file <FILE>
	    [--output-sequence-file <FILE>] [--output-dir <FILE>]
	
	Description:
	    Append the input BLAST query to the sequence import file.
	
	Options:
	    --blast-query-file        path to file containing the BLAST query sequence
	    --output-sequence-file    path to output sequence file that the input sequence gets appended to
	    --output-dir              path to directory containing input files for the EST job

Reference
---------


NAME
----

append_blast_query.pl - append the input BLAST query to the sequence
import file



SYNOPSIS
--------

::

    # Read <FILE.fa> and append to <PATH/TO/all_sequences.fasta>
    append_blast_query.pl --blast-query-file <FILE.fa> --output-sequence-file <PATH/TO/all_sequences.fasta>
    
    # Read <FILE.fa> and append to <OUTPUT_DIR/all_sequences.fasta>
    append_blast_query.pl --blast-query-file <FILE.fa> --output-dir <OUTPUT_DIR>

    # Read <FILE.fa> and append to all_sequences.fasta in the current working directory
    append_blast_query.pl --blast-query-file <FILE.fa>



DESCRIPTION
-----------

BLAST import option for EST generates import sequences that are used for
the all-by-all BLAST later in the pipeline. By default the query
sequence (the sequence the user provided for the BLAST option) is not
included in the import sequences. This script takes that query sequence
and appends it to the import sequence file.
