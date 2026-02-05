get_sequences
=============
Usage
-----

::

	Usage: perl pipelines/shared/perl/get_sequences.pl [--output-dir <OUTPUT_DIR>]
	    --fasta-db <BLAST_DB> [--sequence-ids-file <ACCESSION_IDS_FILE>]
	    [--output-sequence-file <FASTA_FILE>]
	
	Description:
	    Retrieve the FASTA sequences for each ID in a file with UniProt accession
	    IDs
	
	Options:
	    --output-dir              If not specified, defaults to current working directory
	    --fasta-db                Path to BLAST-formatted sequence database
	    --sequence-ids-file       Path to text file containing list of accession IDs
	    --output-sequence-file    Path to output file to put sequences in

Reference
---------


NAME
----

get_sequences.pl - retrieve the FASTA sequences for each ID in a file
with UniProt accession IDs



SYNOPSIS
--------

::

   get_sequences.pl --fasta-db <BLAST_DATABASE> --sequence-ids-file accession_ids.txt --output-sequence-file all_sequences.fasta



DESCRIPTION
-----------

``get_sequences.pl`` retrieves sequences from a BLAST-formatted
database. The sequences that are retrieved are specified in an input
file provided on the command line.



Arguments
~~~~~~~~~

``--fasta-db``
   The path to a BLAST-formatted database that was built using a set of
   FASTA sequences.

``--output-dir`` (optional, defaults)
   The directory to read and write the input and output files from and
   to. Defaults to the current working directory if not specified.

``--sequence-ids-file`` (optional, defaults)
   The path to the input file containing a list of sequence IDs. If this
   is not specified, the file with the name corresponding to the
   ``accession_ids`` value in the **``EFI::Import::Config::Defaults``**
   module is used from the output directory.

``--output-sequence-file`` (optional, defaults)
   The path to the output file containing all of the FASTA sequences
   that were retrieved from the database. If this is not specified, the
   file with the name corresponding to the ``all_sequences`` value in
   the **``EFI::Import::Config::Defaults``** module is used in the
   output directory.
