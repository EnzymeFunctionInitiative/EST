AttributeWriter.pm
==================

Reference
---------


EFI::SSN::AttributeWriter
=========================



NAME
----

**EFI::SSN::AttributeWriter** - Perl module for rewriting a XGMML file
from a source to a target while inserting color and cluster number
information



SYNOPSIS
--------

::

   use EFI::SSN::AttributeWriter;
   use EFI::SSN::AttributeWriter::Handler::Color;

   my $colorHandler = EFI::SSN::AttributeWriter::Handler::Color->new(cluster_map => $clusterMap, colors => $colors);

   my $xwriter = EFI::SSN::AttributeWriter->new(ssn => $inputSsn, output_file => $outputSsn, append_new_attr => 1);
   $xwriter->addAttributeHandler($colorHandler);
   $xwriter->write();



DESCRIPTION
-----------

**EFI::SSN::AttributeWriter** is a Perl module for stream reading XGMML
files and writing them to a new XGMML file while including metadata for
nodes (e.g. things like colors, cluster numbers, etc.). The
**EFI::SSN::AttributeWriter::Handler** and derived classes are used to
provide metadata.



METHODS
-------



``new(ssn => $ssnFile, output_file => $outputSsn, append_new_attr => 1)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::SSN::AttributeWriter** object.



Parameters
^^^^^^^^^^

``ssn``
   Path to a SSN file in XGMML format (XML) that is to be parsed.

``output_file``
   Path to the SSN file to write.

``append_new_attr``
   If true (non-zero), then new attributes are appended after the node
   attribute location specified by **EFI::Annotations** (e.g.
   ``get_cluster_info_insert_location`` and
   ``get_gnt_info_insert_location``). Otherwise the new node attributes
   will be prepended to the location. *Defaults to true (e.g.
   appending).*



Example Usage
^^^^^^^^^^^^^

::

   my $xwriter = EFI::SSN::AttributeWriter->new(ssn => $inputSsn, output_file => $outputSsn,
       append_new_attr => 0);
   # If the location is the node attribute "Organism", then fields will be inserted
   # before the "Organism" attribute and then "Organism" will be added.

``write()``
~~~~~~~~~~~

Parses the XGMML file on a per-element basis and writes the element to
the output SSN. This method doesn't create a DOM; rather it obtains
information from each XML element that is relevant to the input handlers
and copies the element to the output file.



Example Usage
^^^^^^^^^^^^^

::

   $parser->write();



``addAttributeHandler($handler)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Adds a handler to the list of handlers that are called for each node
attribute.



Parameters
^^^^^^^^^^

``$handler``
   An object derived from **EFI::SSN::AttributeWriter::Handler**.



``getStats()``
~~~~~~~~~~~~~~

Returns statistics, such as the number of nodes and edges, which are
computed as the file is written. The statistics can be written to a file
for use by an external application.



Returns
^^^^^^^

Hash ref containing a single key-value, with the key being the output
file name and the value being the statistics that will be written.

::

   # {
   #     "file_name.xgmml" => {
   #         type => "colorssn",
   #         num_nodes => 100,
   #         num_edges => 1000,
   #         size => 10000
   #     }
   # }



Example Usage
^^^^^^^^^^^^^

::

   use EFI::Util::FileStats qw(save_stats);

   my $stats = $xwriter->getStats();

   save_stats("stats.json", $stats);
