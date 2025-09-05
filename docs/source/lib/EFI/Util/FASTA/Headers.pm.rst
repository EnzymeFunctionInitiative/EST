Headers.pm
==========

Reference
---------


EFI::Util::FASTA::Headers
=========================



NAME
----

EFI::Util::FASTA::Headers - Perl module for parsing ID information from
FASTA headers.



SYNOPSIS
--------

::

   use EFI::Util::FASTA::Headers;

   my $parser = new EFI::Util::FASTA::Headers(efi_dbh => $efiDbh); # $efiDbh is required and is a database handle from EFI::Database

   open my $fh, "<", "fasta_file.fasta";

   while (my $line = <$fh>) {
       chomp($line);
       my $header = $parser->parseLineForHeaders($line);
       if ($header) {
           # process header
       } else {
           # process sequence line
       }
   }



DESCRIPTION
-----------

**EFI::Util::FASTA::Headers** is a utility module that parses sequence
IDs out of FASTA headers and maps them to UniProt IDs if they are not a
UniProt ID. Information about the ID is included in the header return
value that can be used for sequence metadata.



METHODS
-------



``new(efi_dbh => $efiDbh)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Create an instance of EFI::IdMapping object.



Parameters
^^^^^^^^^^

``efi_dbh``
   A database connection handle created by the **EFI::Database** object.



``parseLineForHeaders($line)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Determine if a line is a FASTA header, extract ID information, and
return the result.



Parameters
^^^^^^^^^^

``$line``
   A line from a FASTA file, which can contain anything, sequence data,
   blank, or a FASTA sequence header.



Returns
^^^^^^^

If the line is not a FASTA header, return ``undef``.

If the line is a FASTA header, return a hash ref containing the
following values:

``uniprot_id``
   The UniProt ID that is contained in the sequence or that the sequence
   ID mapped back to. If the ID was not detected, this is an empty
   string.

``other_ids``
   An array ref containing a list of unidentified IDs or other UniProt
   IDs that are contained in the same header line.

``query_id``
   If the ID is UniProt or maps to a UniProt ID, this is the value of
   the original ID. For example, if the input was ``"B0SS77"``,
   ``uniprot_id`` is ``"B0SS77"`` and ``query_id`` is ``"B0SS77"``. If
   the input was ``"XP_007754113.1"``, ``query_id`` is
   ``"XP_007754113.1"`` and ``uniprot_id`` is ``"W9WLN6"``.

``raw_header``
   A string containing the entire contents of the header for
   unidentified IDs, and the first 150 characters of the header string
   for UniProt IDs or IDs that map to UniProt IDs.



Example input and output:
^^^^^^^^^^^^^^^^^^^^^^^^^

::

   >sp|B0SS77| Description etc.

       {
           uniprot_id => "B0SS77",
           other_ids => [],
           query_id => "B0SS77",
           raw_header => "Description etc."
       }

   >B0SS77

       {
           uniprot_id => "B0SS77",
           other_ids => [],
           query_id => "B0SS77",
           raw_header => ""
       }

   >XP_007754113.1 metadata and other information

       {
           uniprot_id => "W9WLN6",
           other_ids => ["XP_007754113.1"],
           query_id => "XP_007754113.1",
           raw_header => "metadata and other information"
       }

   >B0SS77|info >XP_007754113.1 metadata and other information

       {
           uniprot_id => "B0SS77",
           other_ids => ["XP_007754113.1"],
           query_id => "B0SS77",
           raw_header => "info XP_007754113.1 metadata and other information"
       }



Example Usage
^^^^^^^^^^^^^

::

   my $header = $parser->parseLineForHeaders($line);
   if ($header->{uniprot_id}) {
       if ($header->{query_id} ne $header->{uniprot_id}) {
           print "Original header ID was $header->{query_id} which mapped to $header->{uniprot_id} UniProt ID.\n";
       } else {
           print "Original header ID was $header->{uniprot_id}\n";
       }
   } else {
       print "No UniProt or mappable IDs detected in the header.\n";
   }

   print "Description: ", $header->{raw_header}, "\n";
   print "Other IDs that were contained in the header include: ", join(", ", @{ $header->{other_ids} }), "\n";
