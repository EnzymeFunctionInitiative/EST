Import Sequences
================

EST analyzes protein sequences. Sequences can import sequences in one of four ways:
 * **Sequence BLAST**: A single FASTA record is provided. It is BLASTed against
   the chosen database (UniProt, UniRef90, or UniRef50) and the matches are used
   in the pipeline.

 * **Families**: A list of protein family identifiers is provided. Family
   identifiers are used to lookup accession IDs, which are then used to lookup
   sequences.

 * **FASTA**: When custom sequences are desired, the user may pass a FASTA file
   directly into the pipeline.

 * **Accession IDs**: IDs are used to look up sequences.

Commandline Usage
-----------------

Import consists of collecting accession IDs and retrieving sequences. Both
scripts need to be run for all input types because the accession retrieval
script also filters the accessions.

To get IDs and sequences from a BLAST, ::

    perl get_sequence_ids.pl --efi-config <EFI_CONFIG> --efi-db <EFI_DB> --output-dir <OUTPUT_DIR> --mode blast --blast-query <USER_BLAST_QUERY_FILE>
    perl append_blast_query.pl --blast-query <USER_BLAST_QUERY_FILE> --output-dir <OUTPUT_DIR>
    perl get_sequences.pl --fasta-db <FASTA_DB_PATH> --output-dir <OUTPUT_DIR>

To get IDs and sequences from one or more families, ::
    
    perl get_sequence_ids.pl --efi-config <EFI_CONFIG> --efi-db <EFI_DB> --output-dir <OUTPUT_DIR> --mode family --family <FAMILY>
    perl get_sequences.pl --fasta-db <FASTA_DB_PATH> --output-dir <OUTPUT_DIR>

To get IDs and sequences from a FASTA file, ::

    perl get_sequence_ids.pl --efi-config <EFI_CONFIG> --efi-db <EFI_DB> --output-dir <OUTPUT_DIR> --mode fasta --fasta <USER_FASTA_FILE>
    perl import_fasta.pl --uploaded-fasta <USER_FASTA_FILE> --output-dir <OUTPUT_DIR>

To get IDs and sequences from an accession ID file, ::

    perl get_sequence_ids.pl --efi-config <EFI_CONFIG> --efi-db <EFI_DB> --output-dir <OUTPUT_DIR> --mode accession --accessions <USER_ACCESSIONS_FILE>
    perl get_sequences.pl --fasta-db <FASTA_DB_PATH> --output-dir <OUTPUT_DIR>

For all four modes:

* If ``--output-dir`` is not provided, the scripts assume that the files are to be
  output and read from the current working directory.

* ``<EFI_CONFIG>`` is the path to the ``efi.config`` file as specified below.

* ``<EFI_DB>`` is the path to the SQLite database file, or the name of the MySQL database.

* ``<FASTA_DB_PATH>`` is the path to the BLAST database containing the FASTA
  sequences to be extracted.

Databases
---------
The import scripts rely on two databases: a BLAST database from which to pull
sequences and a SQL database which contains ID translations and metadata such as
taxonomy.

BLAST database
~~~~~~~~~~~~~~
When import options such as Family and Accession ID are used, the import stage
pull sequences from a BLAST database using ``fastacmd``. EFITools was designed
to work with sequences from UniProt, UniRef90, and UniRef50 and accordingly the
servers for the web version maintain copies of these databases.

SQL Database
~~~~~~~~~~~~
The SQL database is used by ``get_sequence_ids.pl`` to aid in filtering
sequences by family, taxonomy, and fragment status. Every sequence in the BLAST
database should have an entry in the SQL database.

One of the parameters required by the EST pipeline is ``efi.config``. This
should be a file like the following: ::

    [database]
    user=<sql database username>
    password=<password for database user>
    host=<URL or IP address of database server>
    port=<port that database is bound to, usuablly 3306 for MySQL>
    dbi=<sqlite|mysql>

Reference
---------

.. toctree::
    :glob:
    :maxdepth: 1

    *



