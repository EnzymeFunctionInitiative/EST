Import Sequences
================

EST analyzes protein sequences. Sequences can import sequences in one of four ways:
 * **Sequence BLAST**: A single FASTA record is provided. It is BLASTed against
   the chosen database (UniProt, UniRef90, or UniRef50) and the matches are used
   in the pipeline.

 * **Families**: A list of protein familiy identifiers is provided. Family
   identifiers are used to lookup accession IDs, which are then used to lookup
   sequeneces.

 * **FASTA**: When custom sequences are desired, the user may pass a FASTA file
   directly into the pipeline.

 * **Accession IDs**: IDs are used to look up sequences.

Commandline Usage
-----------------

Import consists of collecting accession IDs and retrieving sequences. Both
scripts need to be run for all input types because the accession retrival script
also filters the accessions.

To get accession IDs, 
```
perl src/est/import/get_sequence_ids.pl ...
```

To get sequences,
```
perl src/est/import/get_sequneces.pl ...
```