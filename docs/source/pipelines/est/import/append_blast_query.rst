append_blast_query
==================
Usage
-----

::

	Usage: perl pipelines/est/import/append_blast_query.pl --blast-query-file path_to_file
	    [--output-sequence-file <path/to/output/sequences/file.fasta>]
	    [--output-dir <path/to/output/dir>]
	
	Description:
	    Append the input BLAST query to the sequence import file
	
	Options:
	    --blast-query-file      file that contains the BLAST query sequence
	    --output-sequence-file  file that contains the sequences already retrieved by the pipeline
	    --output-dir            directory that contains the files for the job
	

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
