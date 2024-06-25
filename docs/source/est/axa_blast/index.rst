All-by-All BLAST
================

The All-by-All BLAST stage generates a pairwise distance matrix [1]_ for all
sequences in the input. BLAST is used to compute a *distance metric*, not to
search for sequences. Every sequence which is BLASTed against the database is
already in the database (created in an earlier stage). EFI uses BLAST version
2.2.26 which does not support multithreading. Instead, the input FASTA file is
:doc:`split <../split_fasta/index>` into shards and the shards are run in
parallel.

After BLAST completes, the output is trancoded to parquet and then accession IDs
for the query and subject are sorted lexicographically. This ensures that
symmetric pairs of accessions do not both get included in the output.

BLAST is used as a faster alternative to a `pairwise alignment
<https://en.wikipedia.org/wiki/Sequence_alignment#Pairwise_alignment>`_ or a
Multiple Sequence Alignment.

.. toctree::
    transcode_blast.rst
    render_prereduce_sql_template.rst
    :maxdepth: 1

.. [1] The matrix is positive and hollow but may not satisfy the triangle inequality.