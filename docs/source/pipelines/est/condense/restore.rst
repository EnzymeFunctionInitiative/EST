Restoring Condensed Redundant Sequences
=======================================

Redundant sequence condensation only runs when the ``condense`` parameter is set to true
(set to true by default, without any user intervention). It
uses a reference file created in the :doc:`Condensation <index>` stage to add all of the
sequences not used in the analysis back to the output. A sequence which was not used in the
analysis will get the same BLAST output values as the sequence that represented it.

Components
----------

.. toctree::
    transcode_restored_blast
    :maxdepth: 1
