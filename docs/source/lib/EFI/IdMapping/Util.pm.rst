Util.pm
=======

Reference
---------


EFI::IdMapping::Util
====================



NAME
----

EFI::IdMapping::Util - Perl module containing helper functions and
constants to assist in ID mapping.



SYNOPSIS
--------

::

   use EFI::IdMapping::Util qw(check_id_type :ids);

   # Returns UNIPROT
   $type = check_id_type("B0SS77");

   # Returns NCBI
   $type = check_id_type("WP_012388845.1");



DESCRIPTION
-----------

**EFI::IdMapping::Util** provides helper functions and exports constants
for sequence ID mapping from non-UniProt ID types to UniProt IDs.



METHODS
-------



``check_id_type($id)``
~~~~~~~~~~~~~~~~~~~~~~

Determine the type of the given ID based on the structure of the string.



Parameters
^^^^^^^^^^

``$id``
   A string containing an ID type.



Returns
^^^^^^^

One of the known ID type constants, ``UNIPROT``, ``NCBI``, ``GENBANK``,
``GI``, or ``PDB``.



Example Usage
^^^^^^^^^^^^^

::

   if (check_id_type("B0SS77") eq UNIPROT) {
       print "ID is UniProt\n";
   }



ID TYPES
--------

``UNIPROT``
   6-10 characters, starting with an alphabetical character, followed by
   a number, then a sequence of numbers and letters. A homologue
   identifier can be tacked on the end, in the form of ``.#``. For
   example, "B0SS77" or "A0A0D1YF56".

``NCBI``
   2 letters, followed by ``_``, then numbers optionally followed by
   ``.#``. For example, "WP_012388845.1".

Others
   ``GENBANK``, ``PDB``, and ``GI`` are also identified but are not used
   frequently.



CONSTANTS
---------

``AUTO``
   Used by functions to indicate to ID mapping code that the ID should
   be detected from the format.

``UNKNOWN``
   Indicates that a string may or may not be an ID but is not of a known
   format.
