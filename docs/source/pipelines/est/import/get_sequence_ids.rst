get_sequence_ids
================
Usage
-----

::

	Usage: perl pipelines/est/import/get_sequence_ids.pl [--output-dir <OUTPUT_DIR>]
	    --mode blast|family|accession|fasta --efi-config-file <CONFIG_FILE>
	    --efi-db <EFI_DB> [--output-metadata-file <FILE>]
	    [--output-sunburst-ids-file <FILE>] [--output-stats-file <FILE>]
	    [--sequence-ids-file <FILE>] [--sequence-version uniprot|uniref90|uniref50]
	    [--family <ONE_OR_MORE_FAM_IDS>] [--fasta <FASTA_FILE>]
	    [--seq-mapping-file <FILE>] [--accessions <FILE>] [--blast-query <FILE>]
	    [--blast-output <FILE>]
	
	Description:
	    Retrieve sequence IDs from a database or file and saves them for use by a
	    script later in the EST import pipeline
	
	Options:
	    --output-dir                  If not specified, defaults to current working directory
	    --mode                        Specify the type of retrieval to use
	    --efi-config-file             Path to EFI database configuration file
	    --efi-db                      Path to SQLite database file, or MySQL/MariaDB database name
	    --output-metadata-file        Output file to put metadata into (defaults into --output-dir
	    --output-sunburst-ids-file    Output file to put sunburst data into (defaults into --output-dir)
	    --output-stats-file           Output file to put sequence ID statistics into (defaults into --output-dir)
	    --sequence-ids-file           Output file to put sequence IDs into (defaults into --output-dir)
	    --sequence-version            Sequence type to retrieve; defaults to uniprot
	    --family                      One or more protein families (PF#####, IPR######); required for --mode family
	    --fasta                       User-specified FASTA file containing sequences to use for all-by-all; required for --mode fasta
	    --seq-mapping-file            File for mapping UniProt and anonymous IDs in FASTA file (internal)
	    --accessions                  User-specified file containing list of accession IDs to use for all-by-all; required for --mode accession
	    --blast-query                 Path to file containing sequence for initial BLAST; required for --mode blast
	    --blast-output                Output file to put BLAST results into; required for --mode blast

Reference
---------


NAME
----

get_sequence_ids.pl - retrieve sequence IDs from a database or file and
save them for use by a script later in the EST import pipeline



SYNOPSIS
--------

::

   # BLAST import option; init_blast.out is obtained from a BLAST; see below
   get_sequence_ids.pl --mode blast --blast-output init_blast.out --blast-query <QUERY_FILE> --efi-config <EFI_CONFIG_FILE> --efi-db <EFI_DB_FILE>

   # Family import option
   get_sequence_ids.pl --mode family --efi-config <EFI_CONFIG_FILE> --efi-db <EFI_DB_FILE>

   # Accession import option
   get_sequence_ids.pl --mode accession --accessions <USER_ACC_FILE> --efi-config <EFI_CONFIG_FILE> --efi-db <EFI_DB_FILE>

   # Accession import option
   get_sequence_ids.pl --mode fasta --fasta <USER_FASTA_FILE> --efi-config <EFI_CONFIG_FILE> --efi-db <EFI_DB_FILE>



DESCRIPTION
-----------

This script retrieves sequence IDs from a database or file and saves
them for use by a script later in the EST import pipeline. There are
four EST import modes available: BLAST, Family, Accessions, and FASTA.
See ``import_fasta.pl`` for extra functionality required to complete the
FASTA import option. In addition to outputting a file containing
sequence identifiers, a metadata file is output that contains basic
information about the sequences (e.g. how they were obtained).



MODES
-----



**BLAST**
~~~~~~~~~

The BLAST import option takes output from a BLAST and retrieves the IDs.
For example, the BLAST step might look like this:

::

   # First, sequences are obtained via a BLAST
   #blastall -p blastp -i <QUERY_FILE> -d <BLAST_IMPORT_DB> -m 8 -e <BLAST_EVALUE> -b <BLAST_NUM_MATCHES> -o init_blast.out
   #awk '! /^#/ {print \$2"\t"\$11}' init_blast.out | sort -k2nr > blast_hits.tab

``QUERY_FILE`` is the path to the file that contains the user-specified
query. ``BLAST_IMPORT_DB`` is the path to a BLAST-formatted database.
``BLAST_EVALUE`` and <BLAST_NUM_MATCHES> are the e-value to use and the
maximum number of matches to return from the BLAST, respectively. The
process generates a ``blast_hits.tab`` file. Assuming the process
completed successfully, the next step is to run this script. An
additional output from the script is the ``blast_hits.tab`` file, which
is used during SSN generation for the BLAST import option only.



Example Usage
^^^^^^^^^^^^^

::

   get_sequence_ids.pl --mode blast --blast-output init_blast.out --blast-query <QUERY_FILE> --efi-config <EFI_CONFIG_FILE> --efi-db <EFI_DB_FILE>



Parameters
^^^^^^^^^^

``--blast-output``
   The file from the BLAST to parse.

``--blast-query``
   The file that contains the user FASTA query sequence.



**Family**
~~~~~~~~~~

The Family import option uses one or more protein families to retrieve a
list of IDs. The families that are supported are Pfam, InterPro, Pfam
clans, SSF, and GENE3D.



Example Usage
^^^^^^^^^^^^^

::

   get_sequence_ids.pl --mode family --family PF05544,IPR007197
   get_sequence_ids.pl --mode family --family PF05544 --family IPR007197



Parameters
^^^^^^^^^^

``--family``
   Specify one or more families by using multiple ``--family``
   arguments, or a single ``--family`` argument with one or more
   families separated by commas. Families are specified using the
   following formats: **Pfam**: ``PF#####``, **InterPro**:
   ``IPR######``, **Pfam clans**: ``CL####``, **SSF**: ``SSF#####``, and
   **GENE3D**: ``G3DSA...``.



**Accession**
~~~~~~~~~~~~~

The Accession import option loads sequence IDs from a user-specified
file. The file is parsed to identify UniProt sequence IDs, and if
non-UniProt IDs are detected, attempts to map those back to UniProt IDs.
The result is a file with only UniProt IDs.



Example Usage
^^^^^^^^^^^^^

::

   get_sequence_ids.pl --mode accession --accessions <USER_ACC_FILE>



Parameters
^^^^^^^^^^

``--accessions``
   A path to a file containing sequence IDs. Each identifier should be
   on a separate line.



**FASTA**
~~~~~~~~~

The FASTA import option parses sequence IDs from FASTA headers in a
user-specified FASTA file. The headers are parsed to identify UniProt
sequence IDs, and if non-UniProt IDs are detected, attempts to map those
back to UniProt IDs. The result is an accession ID list file with only
UniProt IDs. Additionally, if sequences could not be identified as
UniProt or mapped to UniProt, anonymous sequence IDs are assigned that
begin with the letters ``ZZ``.



Example Usage
^^^^^^^^^^^^^

::

   get_sequence_ids.pl --mode fasta --fasta <USER_FASTA_FILE>



Parameters
^^^^^^^^^^

``--fasta``
   A path to a file containing FASTA sequences. Identifiers are pulled
   from the sequence headers in the file.

``--seq-mapping-file`` (optional, defaults)
   This file is necessary to map UniProt or anonymous identifiers to the
   proper header line in the input FASTA file. The file is provided to
   the **``import_fasta.pl``** script which reformats the user FASTA
   file into an acceptable format with proper header IDs. If this is not
   specified, the file is named according to the ``seq_mapping`` value
   in the **``EFI::Import::Config::Defaults``** module and put in the
   output directory.



Shared Arguments
~~~~~~~~~~~~~~~~

The import options share a number of arguments.

``--sequence-ids-file`` (optional, defaults)
   The output file that the IDs from the sequence ID retrieval are
   stored in. If this is not specified, the file is named according to
   the ``accession_ids`` value in the
   **``EFI::Import::Config::Defaults``** module and put in the output
   directory.

``--mode`` (required)
   Specifies the mode; supported values are ``blast``, ``family``, and
   ``accession``.

``--efi-config`` (required)
   The path to the config file used for the database.

``--efi-db`` (required)
   The path to the SQLite database file or the name of a MySQL/MariaDB
   database. The database connection parameters are specified in the
   ``--efi-config`` file.

``--sequence-version`` (optional, defaults)
   UniProt, UniRef90, and UniRef50 sequences can be retrieved.
   Acceptable values are ``uniprot`` (default), ``uniref90``, and
   ``uniref50``. When this version is ``unirefXX``, the sequences
   retrieved from the BLAST and Family import options are UniRefXX
   sequences only. When the import option is Accession, all sequences in
   the import file are used, including ones that are not UniRefXX.

``--output-dir`` (optional, defaults)
   This is the directory to store files in if they are not specified as
   arguments. If it is not specified, the current working directory is
   used.

``--output-metadata-file`` (optional, defaults)
   The script also outputs a metadata file (see
   **``EFI::EST::Metadata``** for the format of this file). If this is
   not specified, the file is named according to the
   ``sequence_metadata`` value in the
   **``EFI::Import::Config::Defaults``** module and put in the output
   directory.

``--output-sunburst-ids-file-`` (optional, defaults)
   The EST graphical tools support the display of taxonomy in the form
   of sunburst diagrams. If this is not specified, the file is named
   according to the ``sunburst_ids`` value in the
   **``EFI::Import::Config::Defaults``** module and put in the output
   directory.

``--output-stats-file`` (optional, defaults)
   Statistics are computed for the sequences that are retrieved (e.g.
   size of family, number of sequences). If this is not specified, the
   file is named according to the ``import_stats`` value in the
   **``EFI::Import::Config::Defaults``** module and put in the output
   directory.
