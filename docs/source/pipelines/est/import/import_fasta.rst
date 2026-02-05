import_fasta
============
Usage
-----

::

	Usage: perl pipelines/est/import/import_fasta.pl [--output-dir <OUTPUT_DIR>]
	    --uploaded-fasta <FASTA_FILE> [--seq-mapping-file <FILE>]
	    [--output-sequence-file <FASTA_FILE>]
	
	Description:
	    Import user-specified FASTA sequences into a form usable by the SSN
	    creation pipeline
	
	Options:
	    --output-dir              If not specified, defaults to current working directory
	    --uploaded-fasta          User-specified FASTA file containing sequences to use for all-by-all
	    --seq-mapping-file        File for mapping UniProt and anonymous IDs in FASTA file (internal); defaults into --output-dir
	    --output-sequence-file    Path to output file to put sequences in; defaults into --output-dir

Reference
---------


NAME
----

import_fasta.pl - import user-specified FASTA sequences into a form
usable by the SSN creation pipeline instead of using
``get_sequences.pl``.



SYNOPSIS
--------

::

   import_fasta.pl --uploaded-fasta-file <PATH/TO/FASTA_file>



DESCRIPTION
-----------

For all import methods but FASTA, the ``get_sequences.pl`` script is
used. This script is a replacement for that and is designed to work with
FASTA sequences that do not have a proper sequence ID. It assigns
anonymous sequence identifiers to the sequences and writes them to the
standard ``all_sequences`` file that is outputted from
``get_sequences.pl``.



Arguments
~~~~~~~~~

``--uploaded-fasta-file`` (required)
   The path to the user-specified FASTA file.

``--output-dir`` (optional, defaults)
   The directory to read and write the input and output files from and
   to. Defaults to the current working directory if not specified.

``--seq-mapping-file`` (optional, defaults)
   When ``get_sequence_ids.pl`` is run in the FASTA mode, it outputs a
   file that maps lines in the original user-specified FASTA file to
   anonymous sequence identifiers. If this is not specified, the file
   with the name corresponding to the ``seq_mapping`` value in the
   **``EFI::Import::Config::Defaults``** module is used in the output
   directory.

   This file is a two column format file with a header line, where the
   first column is the UniProt or anonymous ID and the second column is
   the line number where the corresponding sequence header is located in
   the ``--user-uploaded-file`` file.

``--output-sequence-file`` (optional, defaults)
   The path to the output file containing all of the FASTA sequences
   that are reformatted and renamed based on the ``--seq-mapping-file``
   file. If this is not specified, the file with the name corresponding
   to the ``all_sequences`` value in the
   **``EFI::Import::Config::Defaults``** module is used in the output
   directory.
