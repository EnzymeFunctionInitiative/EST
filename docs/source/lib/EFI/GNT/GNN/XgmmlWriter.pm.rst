XgmmlWriter.pm
==============

Reference
---------


EFI::GNT::GNN::XgmmlWriter
==========================



NAME
----

**EFI::GNT::GNN::XgmmlWriter** - Perl interface for writing XGMML files
for various GNN types.



SYNOPSIS
--------

::

   # Should never be directly instantiated
   use EFI::GNT::GNN::XgmmlWriter::PfamHub; # or ClusterHub

   my $xwriter = EFI::GNT::GNN::XgmmlWriter::PfamHub->new(output_file => $gnnFile, gnt_anno => $gntAnno);
   $xwriter->open();

   $xwriter->writeField({name => "att_name", type => "string", value => ["1", "2", "3"]});

   $xwriter->writeNode("node1", "Node 1", [{name => "att_field", "value" => "value", type => "string"}]);
   $xwriter->writeNode("node2", "Node 2", [{name => "att_field", "value" => "value", type => "string"}]);
   $xwriter->writeEdge("node1", "node2");

   $xwriter->close();

   my $stats = $xwriter->getStats();



DESCRIPTION
-----------

**EFI::GNT::GNN::XgmmlWriter** is a Perl interface providing standard
API to facilitate writing of various GNN files in XGMML format. It
inherits from **EFI::Xgmml::Writer** to get low-level XML tag access. It
also provides XGMML-specific helper functions that are responsible for
performing low-level XML tag writing.



METHODS
-------



``new(output_file => $outputFile)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::GNT::GNN::XgmmlWriter** object. Should only be
called from sub classes.



Parameters
^^^^^^^^^^

``output_file``
   Path to a file in XGMML format that is to be created.



Example Usage
^^^^^^^^^^^^^

::

   my $xwriter = EFI::GNT::GNN::XgmmlWriter::PfamHub->new(output_file => $outputFile);
   # Or:
   my $xwriter = EFI::GNT::GNN::XgmmlWriter::ClusterHub->new(output_file => $outputFile);



``writeField($fieldData)`` **(protected method)**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Writes the given field data to the file as XML tags in the XGMML ``att``
format. Field data is given as a hash ref with three key-value pairs:
``name``, ``value``, and ``type``. ``type`` is one of **string, real,
integer**. If the ``value`` is an array ref then the output is an 'att'
list field which is a nested list of 'att' tags, each corresponding to
an element in the input list. If the input is invalid then nothing is
written. This documentation is given in order to understand the format
of the input structures, and this function should never be called
directly by inheriting modules.



Parameters
^^^^^^^^^^

``$field``
   Hash ref containing data to write. Three key-values are expected:
   ``name``, ``value``, and ``type``. ``value`` can be an array ref.



Example Usage
^^^^^^^^^^^^^

::

   my $field = {name => "field_name", value => "field_value", type => "string"};
   $xwriter->writeField($field);
   # renders as:   <att name="field_name" value="field_value" type="string" />

   my $field = {name => "field_name", value => "2.0", type => "real"};
   $xwriter->writeField($field);
   # renders as:   <att name="field_name" value="2.0" type="real" />

   my $field = {name => "field_name", value => ["value3", "value2", "value1"], type => "string"};
   $xwriter->writeField($field);
   # renders as:
   # <att name="field_name" type="list">
   #   <att name="field_name" value="value3" type="string" />
   #   <att name="field_name" value="value2" type="string" />
   #   <att name="field_name" value="value1" type="string" />
   # </att>



``writeNode($nodeId, $labelId, $attr)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Writes a node start-end tag pair with the given ID and label parameters
as well as attributes of the node in the form of nested ``att`` tags.



Parameters
^^^^^^^^^^

``$nodeId``
   The node ID (``id`` attribute in the tag)

``$labelId``
   Node label value (``label`` attribute in the tag)

``$attr``
   Array ref of node attributes to be written as nested ``att`` tags.
   See **writeField** for the expected structure of this array ref.



Example Usage
^^^^^^^^^^^^^

::

   my @fields = ({name => "field_name1", value => "field_value", type => "string"},
                 {name => "field_name2", value => "2.0", type => "real"},
                 {name => "field_name3", value => ["value3", "value2", "value1"], type => "string"});
   $xwriter->writeNode("node_id", "node_label", \@fields);

   # renders as:
   # <node id="node_id" label="node_label">
   #   <att name="field_name1" value="field_value" type="string" />
   #   <att name="field_name2" value="2.0" type="real" />
   #   <att name="field_name3" type="list">
   #     <att name="field_name3" value="value3" type="string" />
   #     <att name="field_name3" value="value2" type="string" />
   #     <att name="field_name3" value="value1" type="string" />
   #   </att>
   # </node>



``writeEdge($sourceNodeId, $targetNodeId)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Writes an edge to the file.



Parameters
^^^^^^^^^^

``$sourceNodeId``
   The source node ID

``$targetNodeId``
   The target node Id



Example Usage
^^^^^^^^^^^^^

::

   $xwriter->writeEdge("cluster_id", "pfam_id", "cluster_id to pfam_id");
   # renders as:
   #   <edge source="cluster_id" target="pfam_id" label="cluster_id to pfam_id" />



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
