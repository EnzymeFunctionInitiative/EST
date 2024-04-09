Process BLAST Results
=====================

Filters, summarizes, and plots BLAST output using matplotlib and
computes cumulative-sum table for alignment scores.


Commandline Usage
-----------------

.. highlight:: none

::

    usage: process_blast_results.py [-h] --blast-output BLAST_OUTPUT --job-id JOB_ID [--min-edges MIN_EDGES] [--min-groups MIN_GROUPS]
                                --length-plot-filename LENGTH_PLOT_FILENAME --pident-plot-filename PIDENT_PLOT_FILENAME
                                --edge-hist-filename EDGE_HIST_FILENAME --evalue-tab-filename EVALUE_TAB_FILENAME
                                [--output-type {png,svg,pdf}] [--proxies KEY:VALUE [KEY:VALUE ...]]

    Render plots from BLAST output

    options:
    -h, --help            show this help message and exit
    --blast-output BLAST_OUTPUT
                            7-column output file from BLAST
    --job-id JOB_ID       Job ID number for BLAST output file
    --min-edges MIN_EDGES
                            Minimum number of edges needed to retain an alignment-score group
    --min-groups MIN_GROUPS
                            Minimum number of alignment-score groups to retain in output
    --length-plot-filename LENGTH_PLOT_FILENAME
                            Filename, without extension, to write the alignment length boxplots to
    --pident-plot-filename PIDENT_PLOT_FILENAME
                            Filename, without extension, to write the percent identity boxplots to
    --edge-hist-filename EDGE_HIST_FILENAME
                            Filename, without extension, to write the edge count histograms to
    --evalue-tab-filename EVALUE_TAB_FILENAME
                            Filename to save evalue cumulative sum table to
    --output-type {png,svg,pdf}
    --proxies KEY:VALUE [KEY:VALUE ...]
                            A list of key:value pairs for rendering smaller proxy images. Keys wil be included in filenames, values
                            should be less than 96

Functions
---------

.. automodule:: visualization.process_blast_results
    :members: