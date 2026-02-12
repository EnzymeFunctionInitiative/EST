Condensing Redundant Sequences
==============================

Condensing redundant sequences (enabled by default) is an extra step taken before BLAST
to speed up the analysis of some datasets. It is enabled by default. This step uses
`CD-HIT <https://sites.google.com/view/cd-hit>`_
to pick representative sequences as proxies for groups of sequences. The representative
sequences are used in the All-by-All BLAST.

Condensation can be disabled by setting the ``condense`` parameter to ``false`` in
the nextflow parameters file or by passing ``--no-condense`` to
``bin/create_est_nextflow_params.py``.

.. toctree::
    restore
    transcode_restored_blast
    :maxdepth: 1
