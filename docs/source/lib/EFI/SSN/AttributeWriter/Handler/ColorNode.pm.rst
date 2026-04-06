ColorNode.pm
============

Reference
---------


EFI::SSN::AttributeWriter::Handler::ColorNode
=============================================



NAME
----

**EFI::SSN::AttributeWriter::Handler::ColorNode** - Perl module for
saving color attributes based on node ID into a SSN.



SYNOPSIS
--------

::

   use EFI::SSN::AttributeWriter;
   use EFI::SSN::AttributeWriter::Handler::ColorNode;

   my $xwriter = EFI::SSN::AttributeWriter->new(ssn => $inputSsn, output_ssn => $outputSsn);

   my $colorHandler = EFI::SSN::AttributeWriter::Handler::ColorNode->new(color_map => $nodeColorMap,
       overwrite_fillcolor => 1);
   $xwriter->addAttributeHandler($colorHandler);

   $xwriter->write();



DESCRIPTION
-----------

**EFI::SSN::AttributeWriter::Handler::ColorNode** is a Perl module that
is a node handler used by **EFI::SSN::AttributeWriter** to insert
attributes into an XGMML file that is being written. This handler saves
a new node attribute and/or overwrites the ``node.fillColor`` node
attribute using colors specified in a color mapping parameter.



METHODS
-------



``new(color_map => $nodeColorMap)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::SSN::AttributeWriter::Handler::ColorNode** object;



Parameters
^^^^^^^^^^

``color_map``
   Hash ref that maps sequence ID (node label) to color and neighborhood
   connectivity value. For example:

   ::

      {
          "SEQID" => ["#000000", 3.14],
          ...
      }

``overwrite_fillcolor``
   Set to true to overwrite the ``node.fillColor`` SSN attribute, false
   (or not specified) to store the color in the
   **EFI::Annotations::Fields::FIELD_NB_CONN_COLOR** column.



``getStats()``
~~~~~~~~~~~~~~

Returns statistics.



Returns
^^^^^^^

A hash ref containing the number of nodes in the SSN.
