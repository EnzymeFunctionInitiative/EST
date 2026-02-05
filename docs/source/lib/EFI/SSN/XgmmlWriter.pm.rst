XgmmlWriter.pm
==============

Reference
---------


EFI::SSN::XgmmlWriter
=====================



NAME
----

EFI::SSN::XgmmlWriter - Perl module for rewriting a XGMML file from a
source to a target while inserting color and cluster number information



SYNOPSIS
--------

::

   use EFI::SSN::XgmmlWriter;
   use EFI::SSN::XgmmlWriter::AttributeHandler::Color;

   my $colorHandler = EFI::SSN::XgmmlWriter::AttributeHandler::Color(cluster_map => $clusterMap, colors => $colors);

   my $xwriter = EFI::SSN::XgmmlWriter->new(ssn => $inputSsn, output_ssn => $outputSsn);
   $xwriter->addAttributeHandler($colorHandler);
   $xwriter->write();



DESCRIPTION
-----------

**EFI::SSN::XgmmlWriter** is a Perl module for stream reading XGMML
files and writing them to a new XGMML file while including metadata for
nodes (e.g. things like colors, cluster numbers, etc.). The
**EFI::SSN::XgmmlWriter::AttributeHandler** and derived classes are used
to provide metadata.



METHODS
-------



``new(ssn => $ssnFile, output_ssn => $outputSsn)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::SSN::XgmmlWriter** object.



Parameters
^^^^^^^^^^

``ssn``
   Path to a SSN file in XGMML format (XML) that is to be parsed and
   rewritten.



Example Usage
^^^^^^^^^^^^^

::

   my $xwriter = EFI::SSN::XgmmlWriter->new(ssn => $inputSsn, output_ssn => $outputSsn);

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
   An object derived from **EFI::SSN::XgmmlWriter::AttributeHandler**.
