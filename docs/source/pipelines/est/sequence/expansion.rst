Redundancy Expansion
====================

Redundancy expansion only runs when the ``collapse-redundancy`` parameter was set to true. It
uses a reference file created in the :doc:`Redundancy <../sequence/redundancy>` stage to add all of the
sequences not used in the analysis back to the output. A sequence which was not
used in the analysis will get the same BLAST output values as the sequence that
represented it.

Components
----------

.. toctree::
    transcode_expanded_blast
    :maxdepth: 1
