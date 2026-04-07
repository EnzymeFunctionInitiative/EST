Color.pm
========

Reference
---------


EFI::SSN::AttributeWriter::Handler::Color
=========================================



NAME
----

**EFI::SSN::AttributeWriter::Handler::Color** - Perl module for saving
color attributes based on cluster number into a SSN.



SYNOPSIS
--------

::

   use EFI::SSN::AttributeWriter;
   use EFI::SSN::AttributeWriter::Handler::Color;

   my $xwriter = EFI::SSN::AttributeWriter->new(ssn => $inputSsn, output_ssn => $outputSsn);

   my $colorHandler = EFI::SSN::AttributeWriter::Handler::Color->new(cluster_map => $clusterMap,
       colors => $colors, cluster_sizes => $sizes);
   $xwriter->addAttributeHandler($colorHandler);

   $xwriter->write();

   my $clusterColors = $colorHandler->getClusterColors();
   map { print join("\t", $_, $clusterColors->{$_}), "\n"); } sort { $a <=> $b } keys %$clusterColors;



DESCRIPTION
-----------

**EFI::SSN::AttributeWriter::Handler::Color** is a Perl module that is a
node handler used by EFI::SSN::AttributeWriter to insert attributes into
an XGMML file that is being written. This handler saves new node
attributes into each node that specifies colors based on the cluster
number. The node attributes are inserted into the node at a location
that is determined by a method in the **EFI::Annotations** class.



METHODS
-------



``new(cluster_map => $clusterMapSizes, colors => $colors, cluster_sizes => $sizes)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::SSN::AttributeWriter::Handler::Color** object and
uses the given parameters to determine node colors.



Parameters
^^^^^^^^^^

``cluster_map``
   Hash ref with two keys:

   ``size`` with a hash ref value that maps cluster number by sequence
   to a list of sequence IDs (e.g. node label) in the cluster.

   ``node`` with a hash ref value that maps cluster number by node to a
   list of sequence IDs (e.g. node label) in the cluster.

``colors``
   A **EFI::Util::Colors** object used for retrieving the color of a
   node based on cluster number.

``cluster_sizes``
   A hash ref that contains the sizes of clusters, by number of
   sequences and number of nodes. For example:

   ::

      {
          seq => {
              1 => 99,
              2 => 95,
              ...
          },
          node => {
              1 => 95,
              2 => 94,
          }
      }



``getClusterColors()``
~~~~~~~~~~~~~~~~~~~~~~

Returns a mapping of cluster numbers (based on number of sequences) to
color.



Returns
^^^^^^^

A hash ref of cluster number to hex color.
