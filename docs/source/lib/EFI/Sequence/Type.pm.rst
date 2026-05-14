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

   my $seqId = "B0SS77:1:100";
   print "Sequence $seqId is ", get_sequence_type($seqId), "\n";

   my $seqNum = 42;
   print "New unknown ID is: ", make_unknown_sequence($seqNum), "\n";



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

One of ``SEQ_UNIPROT``, ``SEQ_UNIREF50``, ``SEQ_UNIREF90``, or
``SEQ_REPNODE``. If the input is identified as UniRef90 or UniRef50 then
``SEQ_UNIREF90`` or ``SEQ_UNIREF50`` are returned, or the input is
identified as a RepNode then ``SEQ_REPNODE`` is returned, otherwise for
all other values ``SEQ_UNIPROT`` is returned.



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



``make_unknown_sequence($seqNumber)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates an unknown ID from the given sequential number. The return is a
10-character string beginning with ZZ and followed by additional Zs and
numbers.



Parameters
^^^^^^^^^^

``$seqCount``
   The sequence number (integer) to format into an unknown sequence ID.



Returns
^^^^^^^

String containing the new ID.



Example Usage
^^^^^^^^^^^^^

::

   my $seqNumber = 42;
   my $id = make_unknown_sequence($seqNumber);
   print "Unknown sequence ID is: $id\n";
   # The result is:
   #    Unknown sequence ID is: ZZZZZZZZ42



CONSTANTS
---------

``SEQ_UNIPROT``
   For UniProt (``uniprot``) ID types.

``SEQ_UNIREF50``
   For UniRef50 (``uniref50``) ID types.

``SEQ_UNIREF90``
   For UniRef90 (``uniref90``) ID types.

``SEQ_REPNODE``
   For RepNode (``repnode``) ID types (these come from representative
   node networks).

``SEQ_FULL``
   For IDs that represent full sequences.

``SEQ_DOMAIN``
   For IDs that represent family domain portions of a sequence.



``get_sequence_type($id)``
~~~~~~~~~~~~~~~~~~~~~~~~~~

Indicates if a sequence is a family domain sequence (e.g. a subset that
corresponds to the family-defined start and end position in the sequence
string) or full sequence. Domain sequence IDs contain a colon ``:``
character.



Parameters
^^^^^^^^^^

``$id``
   The sequence ID to check.



Returns
^^^^^^^

``SEQ_DOMAIN`` if the sequence is a domain sequence ID, ``SEQ_FULL`` if
the sequence is a full sequence.



Example Usage
^^^^^^^^^^^^^

::

   my $seqId = "B0SS77";
   print "Sequence $seqId is ", get_sequence_type($seqId), "\n";
   #prints "Sequence B0SS77 is full"
   my $seqId = "B0SS75:1:100";
   print "Sequence $seqId is ", get_sequence_type($seqId), "\n";
   #prints "Sequence B0SS75 is domain"



``strip_domain($id)``
~~~~~~~~~~~~~~~~~~~~~

Strips any domain-related regions from the sequence ID. For example, if
an ID is ``B0SS77:23:500``, the actual ID is ``B0SS77`` and the domain
data is ``23:500``.



Parameters
^^^^^^^^^^

``$id``
   Sequence ID, with or without domain regions.



Returns
^^^^^^^

Sequence ID without domain regions.



Example Usage
^^^^^^^^^^^^^

::

   my $inputSeqId = "B0SS77";
   my $seqId = strip_domain($inputSeqId);
   print "$inputSeqId without domain region is $seqId\n";
   # "B0SS77 without domain region is B0SS77"

   my $inputSeqId = "B0SS77:23:500";
   my $seqId = strip_domain($inputSeqId);
   print "$inputSeqId without domain region is $seqId\n";
   # "B0SS77:23:500 without domain region is B0SS77"
