IdMapping.pm
============

Reference
---------


EFI::IdMapping
==============



NAME
----

EFI::IdMapping - Perl utility module for ID and UniRef mapping



SYNOPSIS
--------

::

    use EFI::IdMapping;
    use EFI::IdMapping::Util qw(AUTO);

    my $mapper = new EFI::IdMapping(efi_dbh => $efiDbh, validate_uniprot => 1); # $efiDbh is required and is a database handle from EFI::Database
    
    # Automatically detect ID type based on format
    my $typeHint = AUTO;
    my @searchIds = ("B0SS77", "WP_012388845.1");

    # Return a list of UniProt IDs that were found
    my ($uniprotIds, $noMatchIds, $reverseMapping) = $mapper->reverseLookup($typeHint, @searchIds);

    my $uniprotIds = ['B0S9U5', 'A0ABY2L3C9', 'N1VN18', 'B0SS77'];
    my $uniprotMapping = $mapper->getUniprotMapping(SEQ_UNIREF50, $uniprotIds);



DESCRIPTION
-----------

**EFI::IdMapping** is a utility module that maps non-UniProt IDs
(usually obtained from FASTA headers) to UniProt IDs. It does this by
using the ``idmapping`` table in an EFI database, which is in turn
obtained from the UniProt ID mapping dataset. The most frequent
non-UniProt ID type that is used is **NCBI**, but other types are
supported (as defined in the **EFI::IdMapping::Util** module).

The utility also provides a method for mapping UniProt IDs to
corresponding UniRef50 and UniRef90 sequences.



METHODS
-------



``new(efi_dbh => $efiDbh, validate_uniprot => $flag)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Create an instance of EFI::IdMapping object.



Parameters
^^^^^^^^^^

``efi_dbh``
   A database connection handle created by the **EFI::Database** object.

``validate_uniprot``
   If true, all IDs in the UniProt ID format are checked to see if they
   are in the EFI database. By default this is enabled. If it is
   disabled, then UniProt IDs in the UniProt standard format are
   returned as-is by the mapper without validation.



``reverseLookup($typeHint, @searchIds)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Try to map IDs of unknown format to UniProt IDs.



Parameters
^^^^^^^^^^

``$typeHint``
   ID format guess, a constant from **EFI::IdMapping::Util**. Usually
   ``AUTO``. See **EFI::IdMapping::Util** for all options.

``@searchIds``
   IDs to map back to UniProt.



Returns
^^^^^^^

#. An array ref listing the identified UniProt IDs.

#. An array ref with IDs of a known format but had no match in the EFI
   database.

#. A hash ref containing a mapping of UniProt IDs to a list of source
   IDs.



Example Usage
^^^^^^^^^^^^^

::

   my @searchIds = ("B0SS77", "WP_012388845.1");
   # Return a list of UniProt IDs that were found
   my ($uniprotIds, $noMatchIds, $reverseMapping) = $mapper->reverseLookup(AUTO, @searchIds);
   # $uniProtIds contains ["B0SS77"]
   # $noMatchIds contains []
   # $reverseMapping contains {"B0SS77" => ["B0SS77", "WP_012388845.1"]}



``getUniprotMapping($idType, $uniprotIds)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a mapping between UniProt IDs and corresponding UniRef IDs. If
the ``$idType`` is ``SEQ_UNIREF50``, the output mapping contains both
UniRef50 and UniRef90 IDs, but if the ``$idType`` is ``SEQ_UNIREF50``,
then the output mapping contains only UniRef90 IDs.

If the input type is ``SEQ_UNIREF90``, then the output only contains
UniRef90 IDs:

::

   {
       'UNIPROT_A' => { uniref90 => 'UNIREF90_A' },
       'UNIPROT_B' => { uniref90 => 'UNIREF90_A' },
       'UNIPROT_C' => { uniref90 => 'UNIREF90_B' },
       ...
   }

If the input type is ``SEQ_UNIREF50``, then the output contains both
UniRef50 and UniRef90 IDs:

::

   {
       'UNIPROT_A' => { uniref90 => 'UNIREF90_A', uniref50 => 'UNIREF50_A' },
       'UNIPROT_B' => { uniref90 => 'UNIREF90_A', uniref50 => 'UNIREF50_A' },
       'UNIPROT_C' => { uniref90 => 'UNIREF90_B', uniref50 => 'UNIREF50_A' },
       ...
   }



Parameters
^^^^^^^^^^

``$idType``
   Type of the IDs in the metanode (``SEQ_UNIREF50`` or
   ``SEQ_UNIREF90``)

``$uniprotIds``
   Array ref of UniProt IDs



Returns
^^^^^^^

Returns a hash ref containing a mapping of UniProt ID to the
corresponding UniRef IDs, where each key points to a hash ref containing
one key (``uniref90``, for input type ``SEQ_UNIREF90``) or two keys
(``uniref50``, for input type ``SEQ_UNIREF50``) pointing to sequence
IDs.



Example Usage
^^^^^^^^^^^^^

::

   my $uniprotIds = ['B0S9U5', 'A0ABY2L3C9', 'N1VN18', 'B0SS77'];
   my $uniprotMapping = $mapper->getUniprotMapping(SEQ_UNIREF50, $uniprotIds);

The result of this is:

::

   {
       'B0S9U5' => { uniref90 => 'B0SS77', uniref50 => 'B0SS77' },
       'A0ABY2L3C9' => { uniref90 => 'A0A7I0HR15', uniref50 => 'B0SS77' },
       'N1VN18' => { uniref90 => 'N1VN18', uniref50 => 'B0SS77' },
       'B0SS77' => { uniref90 => 'B0SS77', uniref50 => 'B0SS77' },
   }
