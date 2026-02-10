Condensing Redundant Sequences
==============================

Condensing redundant sequences is an optional step which may speed up the analysis
of some datasets. It uses `CD-HIT <https://sites.google.com/view/cd-hit>`_ to pick
representative sequences as proxies for groups of sequences. The representative
sequences are used in the All-by-All BLAST.

Condensation can be enabled by setting the ``condense`` parameter to ``true`` in
the nextflow parameters file or by passing ``--condense`` to
``bin/create_est_nextflow_params.py``.

.. toctree::
    restore
    transcode_restored_blast
    :maxdepth: 1
