Split FASTA
===========

This stage divides the FASTA file from the import stage into a number of
approximately equally sized shards. This is necessary because EST uses BLAST
2.2.26 which does not support multithreading. Each shard is BLASTed against the
database created earlier.

Commandline Usage
-----------------
The program takes two arguments:
    * `-parts`: the number of shards to create
    * `-source`: the FASTA file to split

Example:

```
$ perl pipelines/est/src/split_fasta/split_fasta.pl -parts 64 -source all_sequences.fasta
```