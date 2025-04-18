Type.pm
=======

Reference
---------


EFI::Sequence::Type
===================



NAME
----

**EFI::Sequence::Type** - Perl module for sequence ID types



SYNOPSIS
--------

::

   use EFI::Sequence::Type;

   print "UniProt\n" if get_sequence_version("uniprot") eq SEQ_UNIPROT;

   my $seqId = "zzzz42";
   print "Sequence $seqId is ", (is_unknown_sequence($seqId) ? "Unknown" : "UniProt-formatted"), "\n";



DESCRIPTION
-----------

**EFI::Sequence::Type** is a utility module with constants representing
sequence ID types and also providing functions for validating ID types.



METHODS
-------



``get_sequence_version($idType)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Compares the input ID type against defined ID types and returns the
appropriate version. Use this to validate input ID type selection (e.g.
through ``--sequence-version`` command line arguments).



Parameters
^^^^^^^^^^

``$idType``
   ID type for which to validate the UniProt version.



Returns
^^^^^^^

One of ``SEQ_UNIPROT``, ``SEQ_UNIREF50``, or ``SEQ_UNIREF90``. If the
input is identified as UniRef90 or UniRef50 then ``SEQ_UNIREF90`` or
``SEQ_UNIREF50`` are returned, otherwise for all other values
``SEQ_UNIPROT`` is returned.



Example Usage
^^^^^^^^^^^^^

::

   print "UniProt\n" if get_sequence_version("UNIPROT") eq SEQ_UNIPROT;
   print "UniRef50\n" if get_sequence_version("uniref50") eq SEQ_UNIREF50;
   print "UniRef90\n" if get_sequence_version("uniref90") eq SEQ_UNIREF90;
   print "UniProt (invalid)\n" if get_sequence_version("invalid") eq SEQ_UNIPROT;



``is_unknown_sequence($id)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Indicates the type of sequence [e.g. UniProt (aka Known) or other (aka
Unknown)]. Unknown IDs start with the ``Z`` character.



Parameters
^^^^^^^^^^

``$id``
   The sequence ID to validate.



Returns
^^^^^^^

``1`` if the ID is unknown, ``0`` if it is UniProt-formatted.



Example Usage
^^^^^^^^^^^^^

::

   my $seqId = "B0SS77";
   print "Sequence $seqId is ", (is_unknown_sequence($seqId) ? "Unknown" : "UniProt-formatted"), "\n";
   my $seqId = "zzzz42";
   print "Sequence $seqId is ", (is_unknown_sequence($seqId) ? "Unknown" : "UniProt-formatted"), "\n";



CONSTANTS
---------

``SEQ_UNIPROT``
   For UniProt (``uniprot``) ID types.

``SEQ_UNIREF50``
   For UniRef50 (``uniref50``) ID types.

``SEQ_UNIREF90``
   For UniRef90 (``uniref90``) ID types.
