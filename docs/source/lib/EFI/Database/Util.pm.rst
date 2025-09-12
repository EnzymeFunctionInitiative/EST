Util.pm
=======

Reference
---------


EFI::Database::Util
===================



NAME
----

**EFI::Database::Util** - Perl module for utility database functions



SYNOPSIS
--------

::

   use EFI::Database::Util;

   my $util = new EFI::Database::Util;

   my @ids = ("UNIPROT1", "UNIPROT2", ...);
   my $sqlPattern = "SELECT * FROM uniref WHERE accession IN (<IDS>)";
   my $idCol = "accession";

   my $matched = $util->batchRetrieveIds(\@ids, $sqlPattern, $idCol);



DESCRIPTION
-----------

**EFI::Database::Util** is a utility module containing helpers for
retrieving data from databases.



METHODS
-------



``batchRetrieveIds($ids, $sqlPattern, $idCol, $allowMultipleId)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Retrieves sequence ID-related information from an EFI database using the
given list of IDs, a SQL pattern, and the ID column relating IDs to the
database. The queries are retrieved in groups of sequences using the SQL
**``WHERE col IN``** syntax for performance reasons. In other words, if
there are 10,000 sequence rows to retrieve, rather than executing 10,000
separate queries with one condition for each ID, the queries are grouped
together in batches of 1,000 IDs, greatly improving the performance of
the retrieval. See the **EFI::Database::Schema** module for the default
number of sequences for the batch retrieval.



Parameters
^^^^^^^^^^

``$ids``
   An array ref containing a list of UniProt sequence IDs.

``$sqlPattern``
   A SQL pattern used to retrieve information from the database. The
   pattern should take the form of
   ``SELECT [cols] FROM [table] WHERE [id_col] IN (<IDS>)`` where
   ``[cols]`` is the list of columns to retrieve from the ``[table]``.
   All IDs in the ``[id_col]`` that match the list of IDs in ``<IDS>``
   will be retrieved. The fields in brackets (e.g. ``[table]`` should be
   replaced with values, removing the brackets. The ``<IDS>`` string
   should be inserted verbatim.

``$idCol``
   The name of the sequence ID column (typically ``accession``) to use
   (should match the ``[id_col]`` value in ``$sqlPattern``.

``$allowMultipleId``
   If true and the ID occurs in multiple rows, the output is stored as a
   list of values.



Returns
^^^^^^^

A hash ref containing a mapping of sequence ID to query results. Note
that only sequences that were found in the database will be returned; if
any of the input IDs do not exist in the database then those IDs will
not be containined in the return value hash.



Example Usage
^^^^^^^^^^^^^

::

   my $sqlPattern = "SELECT * FROM uniref WHERE accession IN (<IDS>)";
   my $idCol = "accession";

   my @ids = ("B0SS77", ...);
   my $matched = $util->batchRetrieveIds(\@ids, $sqlPattern, $idCol);
   foreach my $id (@ids) {
       if ($matched->{$id}) {
           print "UniProt $id has UniRef50 ID $matched->{$id}->{uniref50_seed}\n";
       } else {
           print "$id was NOT found in the database\n";
       }
   }

An example when allowing multiple instances of the same ID:

::

   my $sqlPattern = "SELECT * FROM uniref WHERE uniref50_seed IN (<IDS>)";
   my $idCol = "uniref50_seed";

   my $allowMultipleId = 1;
   my $matched = $util->batchRetrieveIds(\@ids, $sqlPattern, $idCol, $allowMultipleId);
   foreach my $id (@ids) {
       if ($matched->{$id}) {
           my $numIds = @{ $matched->{$id} };
           my $idList = join(", ", map { $_->{accession} } @{ $matched->{$id} });
           print "UniRef50 ID $id has $numId UniProt IDs ($idList)\n";
       } else {
           print "$id was NOT found in the database\n";
       }
   }
