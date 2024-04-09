Visualization
=============

In this stage, the deduplicated BLAST output is processed into several outputs:

* A boxplot of alignment score vs alignment length
* A boxplot of alignment score vs percent identity
* A histogram of alignment score vs edge count
* A tabular file of sorted alignment score values with a cumulative sum
* A histogram of reference sequence lengths

The boxplots, histogram of alignment score/edge count, and tabular file are
all produced by ``process_blast_results.py``. The histogram of reference
sequence lengths is produced by ``plot_length_data.py``.

Components
----------

.. toctree::
    cachemanager.rst
    process_blast_results.rst
    plot_length_data.rst
    plot.rst
    :maxdepth: 1