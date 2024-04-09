Plot Length Data
================

Plot data from length_uniprot.tab and similar files.

Commandline Usage
-----------------

.. highlight:: none

::

    usage: plot_length_data.py [-h] --lengths LENGTHS --job-id JOB_ID [--frac FRAC] --plot-filename PLOT_FILENAME
                           [--title-extra TITLE_EXTRA] [--output-type {png,svg,pdf}] [--proxies KEY:VALUE [KEY:VALUE ...]]

    Render plots from BLAST output

    options:
    -h, --help            show this help message and exit
    --lengths LENGTHS     Tab-separated file containing lengths and counts
    --job-id JOB_ID       Job ID number for BLAST output file
    --frac FRAC           Percent of length values to include in plot
    --plot-filename PLOT_FILENAME
                            Filename, without extension, to write the plots to
    --title-extra TITLE_EXTRA
                            Extra text to include plot title
    --output-type {png,svg,pdf}
    --proxies KEY:VALUE [KEY:VALUE ...]
                            A list of name:dpi pairs for rendering smaller proxy images. Names wil be included in filenames, DPIs
                            should be less than 96

Functions
---------

.. automodule:: visualization.plot_length_data
    :members: