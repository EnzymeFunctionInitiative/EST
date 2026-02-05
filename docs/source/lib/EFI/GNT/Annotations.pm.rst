Annotations.pm
==============

Reference
---------


EFI::GNT::Annotations
=====================



NAME
----

EFI::GNT::Annotations - Perl module for retrieving annotations from the
EFI database.



SYNOPSIS
--------

::

   use EFI::GNT::Annotations;

   my $annoUtil = new EFI::GNT::Annotations(dbh => $dbh);
   my $idData = {id => "B0SS77", pfam => "PF07478-PF01820", interpro => "IPR011761-IPR013815-IPR005905-IPR011095-IPR011127-IPR016185"};
   my $annoData = $annoUtil->getGnnIdAnnotations($idData);

   my $neighbors = ["B0SS77", "B0SS79"];
   my ($neighborData, $numPdb, $numSwissProt) = $annoUtil->getHubAnnotations($neighbors);

   my $shape = $annoUtil->getShape($numPdb, $numSwissProt);



DESCRIPTION
-----------

**EFI::GNT::Annotations** is a Perl module for retrieving metadata
annotations from the EFI database. Metadata retrieved are the organism,
taxonomy ID, annotation status (e.g. TrEMBL or SwissProt), and SwissProt
description.



METHODS
-------



``new(dbh => $dbh)``
~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::GNT::Annotations** object.



Parameters
^^^^^^^^^^

``dbh``
   Database handle that comes from **EFI::Database**.



Example Usage
^^^^^^^^^^^^^

::

   my $annoUtil = new EFI::GNT::Annotations(dbh => $dbh);



``getGnnIdAnnotations($idData)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Retrieves annotations for the accession ID that are necessary to create
a GNN. If the ID doesn't exist in the EFI annotations database, then
``undef`` is returned.



Parameters
^^^^^^^^^^

``$idData``
   A hash ref containing a EFI database accession ID and the associated
   Pfam and InterPro family IDs (multiple can be specified,
   hyphen-separated). For example,

   ::

      {
          id => "B0SS77",
          pfam => "PF07478-PF01820",
          interpro => "IPR011761-IPR013815-IPR005905-IPR011095-IPR011127-IPR016185"
      }



Returns
^^^^^^^

A hash ref with the keys pointing to metadata values:

::

   {
       organism => "organism",

       # NCBI taxonomy ID
       taxonomy_id => 1,

       # 1 for swissprot, 0 otherwise
       status => 1,

       desc => "SwissProt description",

       # description for each input Pfam family ID
       pfam_desc => "Dala_Dala_lig_C;Dala_Dala_lig_N",

       # description for each input InterPro family ID
       interpro_desc => "ATP-grasp;ATP_grasp_subdomain_1;D_ala_D_ala;Dala_Dala_lig_C;Dala_Dala_lig_N;PreATP-grasp_dom_sf"
   }

If the ID doesn't exist in the database then ``undef`` is returned.



Example Usage
^^^^^^^^^^^^^

::

   my $idData = { id => "B0SS77", pfam => "PF07478-PF01820", interpro => "IPR011761-IPR013815-IPR005905-IPR011095-IPR011127-IPR016185" };
   my $annoData = $annoUtil->getGnnIdAnnotations($idData);
   if (not $annoData) {
       print "$id wasn't found in the database\n";
   } else {
       foreach my $annoKey (keys %$annoData) {
           print "$annoKey: $annoData->{$annoKey}\n";
       }
   }



``getFamilyNames($familyHubName)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Retrieves the family names for the families specified in the hub name. A
family hub is one or more Pfam or InterPro family IDs separated by a
hyphen (``-``).



Parameters
^^^^^^^^^^

``$familyHubName``
   Hyphen-separated family IDs (for example, ``PF05544-PF07197``).



Returns
^^^^^^^

Returns three parameters:

``$names``
   An array ref where each element is a hash ref that has three keys
   (``ID``, ``short``, and ``long``). ``short`` is the family short
   name, and ``long`` is the family long name. For example:

   ::

      [
          {family => "PF05544", short => "Pro_racemase", long => "Proline racemase"},
          {family => "PF07197", short => "DUF1409", long => "Protein of unknown function (DUF1409)"}
      ]

``$allShort``
   A string with all of the input family short names joined with
   hyphens, for example ``"Pro_racemase-DUF1409"``.

``$allLong``
   A string with all of the input family long names joined with hyphens,
   for example
   ``"Proline racemase-Protein of unknown function (DUF1409)"``.



Example Usage
^^^^^^^^^^^^^

::

   my $pfamHub = "PF05544-PF07197";
   my ($nameInfo, $allShort, $allLong) = $gntAnno->getFamilyNames($pfamHub);
   foreach my $info (@$nameInfo) {
       print "Family ID: $info->{family}, Short name: $info->{short}, Long name: $info->{long}\n";
   }

   my $pfamDesc = join("; ", map { $_->{long} } grep { $_->{family} =~ m/^PF/ } @$nameInfo);



``getHubAnnotations($ids)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Retrieves PDB and EC number information for all of the input IDs
(usually the Pfam hub neighbors).



Parameters
^^^^^^^^^^

``$ids``
   An array ref where each element is an EFI database accession ID,
   typically hub neighbors.



Returns
^^^^^^^

``$hubData``
   A hash ref that maps input IDs to a string containing
   PDB/EC/SwissProt information.

``$numPdb``
   The number of IDs in the input list that have a PDB number.

``$numSwissProt``
   The number of IDs in the input list that have SwissProt annotations.



Example Usage
^^^^^^^^^^^^^

::

   my $nb = ["B0SS77"];
   my ($data, $numPdb, $numSwissProt) = $annoUtil->getHubAnnotations($nb);



``getShape($numPdb, $numSwissProt)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Returns the shape that the node in the GNN (XGMML) file will have, based
on the number of neighbors in the hub that have PDB numbers and
SwissProt annotations.



Parameters
^^^^^^^^^^

``$numPdb``
   The number of IDs in the input list that have a PDB number.

``$numSwissProt``
   The number of IDs in the input list that have SwissProt annotations.



Returns
^^^^^^^

The shape (as a string) that will be associated with the node in the
output GNN. Available types are: ``diamond`` (has PDB and SwissProt),
``square`` (has PDB but no SwissProt), ``triangle`` (has SwissProt but
no PDB), and ``circle`` (no PDB nor SwissProt).



Example Usage
^^^^^^^^^^^^^

::

   my ($data, $numPdb, $numSwissProt) = $annoUtil->getHubAnnotations([...]);
   my $shape = $annoUtil->getShape($numPdb, $numSwissProt);
   print "The Hub shape will be $shape\n";
