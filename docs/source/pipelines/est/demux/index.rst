Demultiplex
===========

Demultiplexing only runs when the ``multiplex`` parameter was set to true. It
uses a reference file created in the :doc:`Multiplex <../mux/index>` stage to add all of the
sequences not used in the analysis back to the output. A sequence which was not
used in the analysis will get the same BLAST output values as the sequence that
represented it.