Statistics
==========
This stage calculates statistics on the reduced BLAST output which help the user
select the appropriate alignment score to use as a cutoff value. This stage uses
a SQL template to compute a five-number summary on the ``pident`` and
``alignment_length`` columns when grouped by ``alignment_score``. It also
computes a convergence ratio and saves this information to a JSON file.


Components
----------

.. toctree::
    render_boxplotstats_sql_template.rst
    conv_ratio.rst
    :maxdepth: 1

   