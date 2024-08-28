Split FASTA
===========

This stage divides the FASTA file from the import stage into a number of
approximately equally sized shards. This is necessary because EST uses BLAST
2.2.26 which does not support multithreading. Each shard is BLASTed against the
database created earlier.



Reference
---------

.. toctree::
    :glob:
    :maxdepth: 1

    *

