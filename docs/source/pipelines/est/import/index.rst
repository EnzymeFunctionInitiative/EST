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

To get accession IDs,::
    
    perl src/est/import/get_sequence_ids.pl ...


To get sequences,::

    perl src/est/import/get_sequneces.pl ...


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

One of the parameters required by the EST pipeline is ``efi_config``. This
should be a file like the following: ::

    [database]
    user=<sql database username>
    password=<password for database user>
    host=<URL or IP address of database server>
    port=<port that database is bound to, usuablly 3306 for MySQL>
    ip_range=<?>
    name=<name of the database to use. helps when multiple versions are available>
