Multiplex
=========

Multiplexing is an optional step which may speed up the analysis of some
datasets. It uses `CD-HIT <https://sites.google.com/view/cd-hit>`_ to pick
representative sequences as proxies for groups of sequences. The representative
sequences are used in the All-by-All BLAST.

Multiplexing can be enabled by setting the ``multiplex`` parameter to ``true`` in the
nextflow parameters file or by passing ``--multiplex`` to ``create_est_nextflow_params.py``.