GNT.pm
======

Reference
---------


EFI::SSN::AttributeWriter::Handler::GNT
=======================================



NAME
----

**EFI::SSN::AttributeWriter::Handler::GNT** - Perl module for saving
GNT-specific attributes based on cluster number into a SSN.



SYNOPSIS
--------

::

   use EFI::SSN::AttributeWriter;
   use EFI::SSN::AttributeWriter::Handler::GNT;

   my $xwriter = EFI::SSN::AttributeWriter->new(ssn => $inputSsn, output_ssn => $outputSsn);

   my $gntData = {}; # comes from elsewhere
   my $gntHandler = EFI::SSN::AttributeWriter::Handler::GNT->new(gnt_data => $gntData);
   $xwriter->addAttributeHandler($gntHandler);

   $xwriter->write();



DESCRIPTION
-----------

**EFI::SSN::AttributeWriter::Handler::GNT** is a Perl module that is a
node handler used by EFI::SSN::AttributeWriter to insert GNT-specific
attributes into an XGMML file that is being written. This handler saves
five attributes for each **node**:

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



``new(gnt_data => $gntData)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::SSN::AttributeWriter::Handler::GNT** object and
saves the given data object for use when stream reading/writing. The
``gnt_data`` structure is a hash ref that maps sequence IDs (e.g.
node/metanode IDs) to the associated GNT data.



Parameters
^^^^^^^^^^

``gnt_data``
   A hash ref that contains a mapping of node IDs to metadata. The IDs
   can be metanodes or UniProt nodes.



Example Usage
^^^^^^^^^^^^^

::

   # Example data:
   my $gntData = {
       "B0SS77" => {
           present_in_ena => "true",
           has_neighbors => "true",
           ena_id => "ID",
           neighbor_pfams => ["PF", "PF"],
           neighbor_interpro => ["IPR", "IPR", "IPR"],
       },
   };
   # If the network is UniRef50, then example data:
   my $gntData = {
       "B0SS79" => {
           present_in_ena => ["true", "true", "true"],
           has_neighbors => ["true", "true", "true"],
           ena_id => ["ID", "ID", "ID"],
           neighbor_pfams => ["PF", "PF", "PF", "PF", "PF", "PF", "PF", "PF"],
           neighbor_interpro => ["IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR"],
       },
   };

   my $gntHandler = EFI::SSN::AttributeWriter::Handler::GNT->new(gnt_data => $gntData);
   $xwriter->addAttributeHandler($gntHandler);
   # Automatically uses the handler when parsing the file
   $xwriter->write();
