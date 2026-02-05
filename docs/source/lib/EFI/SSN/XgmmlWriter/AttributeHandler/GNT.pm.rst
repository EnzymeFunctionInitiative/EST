GNT.pm
======

Reference
---------


EFI::SSN::XgmmlWriter::AttributeHandler::GNT
============================================



NAME
----

EFI::SSN::XgmmlWriter::AttributeHandler::GNT - Perl module for saving
GNT-specific attributes based on cluster number into a SSN.



SYNOPSIS
--------

::

   use EFI::SSN::XgmmlWriter;
   use EFI::SSN::XgmmlWriter::AttributeHandler::GNT;

   my $xwriter = EFI::SSN::XgmmlWriter->new(ssn => $inputSsn, output_ssn => $outputSsn);

   my $colorHandler = EFI::SSN::XgmmlWriter::AttributeHandler::GNT->new(cluster_map => $clusterMap,
       colors => $colors, cluster_sizes => $sizes);
   $xwriter->addAttributeHandler($colorHandler);

   $xwriter->write();



DESCRIPTION
-----------

**EFI::SSN::XgmmlWriter::AttributeHandler::GNT** is a Perl module that
is a node handler used by EFI::SSN::XgmmlWriter to insert GNT-specific
attributes into an XGMML file that is being written. This handler saves
five attributes for each ``node``:

*Present in ENA Database?*
   This inserts the string ``true`` if the sequence was identified in
   the ENA database, ``false`` if there was no match. Not all ENA
   sequences have UniProt IDs, and sometimes the mapping between ENA ID
   and UniProt doesn't happen for a few UniProt releases after a
   sequence is inserted into the ENA database.

*Genome Neighbors in ENA Database?*
   This contains ``true`` if there the UniProt ID was matched in the ENA
   database and there was one or more neighbor sequences in ENA that
   were matched in UniProt. It is ``false`` otherwise, typically meaning
   that the chromosone consisted of a single protein.

*ENA Database Genome ID*
   This is a the ENA genome ID that maches the UniProt ID.

*Neighbor Pfam Families*
   The Pfam families of each protein neighboring the UniProt/node ID is
   stored in this field. It is a list, and if the node in the SSN is a
   metanode containing more than one ID (e.g. a UniRef ID) then all of
   the families for those nodes are also saved into this field.

*Neighbor InterPro Families*
   The InterPro families of each protein neighboring the UniProt/node ID
   is stored in this field. It is a list, and if the node in the SSN is
   a metanode containing more than one ID (e.g. a UniRef ID) then all of
   the families for those nodes are also saved into this field.



METHODS
-------



``new(cluster_map => $clusterMap, colors => $colors, cluster_sizes => $sizes)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::SSN::XgmmlWriter::AttributeHandler::GNT** object
and uses the given parameters to determine node colors.



Parameters
^^^^^^^^^^

``cluster_map``
   Hash ref that maps sequence ID (e.g. node label) to cluster number.
   Each value is an array ref where the first element is the cluster
   number based on sequences in cluster and the second element is the
   cluster number based on nodes in cluster.

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



Example Usage
^^^^^^^^^^^^^

::

   my $colorHandler = EFI::SSN::XgmmlWriter::AttributeHandler::GNT(cluster_map => $clusterMap,
       colors => $colors, cluster_sizes => $sizes);
   $xwriter->addAttributeHandler($colorHandler);
