Data.pm
=======

Reference
---------


EFI::Sunburst::Data
===================



NAME
----

**EFI::Sunburst::Data** - Perl module that represents a sequence



SYNOPSIS
--------

::

   use EFI::Sunburst::Data;

   my $sequenceIdData = new EFI::Sequence::Collection();
   # Populate $seqData by loading files, see module documentation

   my $sb = new EFI::Sunburst::Data(dbh => $dbh);
   my $data = $sb->getSunburstTaxonomy($sequenceIdData);
   my $json = encode_json($data);
   # Save $json to file



DESCRIPTION
-----------

**EFI::Sunburst::Data** is a Perl module used to retrieve the taxonomic
data for a collection of sequences. This data is designed to be
serialized to a JSON-formatted file for use by sunburst viewers in the
EFI tools.



METHODS
-------



``new(dbh => $dbh)``
~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::Sunburst::Data** instance with a DBI database
handle, used to obtain taxonomic information for a collection of
sequences.



Parameters
^^^^^^^^^^

``dbh``
   Perl DBI database handle.



Example Usage
^^^^^^^^^^^^^

::

   my $sb = new EFI::Sunburst::Data(dbh => $dbh);



``getSunburstTaxonomy($sequenceIdData)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Query the database for the taxonomic hierarchy for every ID in the input
sequence ID collection.



Parameters
^^^^^^^^^^

``$sequenceIdData``
   An object of type **EFI::Sequence::Collection**.



Returns
^^^^^^^

A large heirarchical data structure representing the taxonomy structure
of the input IDs starting with the highest levels (e.g. domain) and
progressively descending to species. Each element of the data structure
is associated with a UniProt ID, also containing the related UniRef IDs.
This is designed to be serialized to JSON and then read by the
Javascript code for displaying sunburst diagrams on the EFI website. The
attribute keys for a given node (e.g. taxonomic category) include:

``"d"``
   The depth in the hierarchy, 0 = Root (for the purposes of the code
   that renders the diagram, 1 = superkingdom/domain, 2 = kingdom, 3 =
   phylum, 4 = class, 5 = order, 6 = family, 7 = genus, and 8 = species.

``"id"``
   A unique identifier, a number.

``"node"``
   The name of the taxonomy category (e.g., "Thermoproteati").

``"nq"``
   The number of UniProt IDs in the input dataset that are in the
   specific category (e.g. species).

``"ns"``
   The number of species (e.g. ``"d"`` = 8) that are children of the
   current category. This is recursive. For example, for a family
   (``"d"`` = 6) this would be the total number of species in that
   family that are in the input dataset (not the number of sequences).

``"parent"``
   The name of the parent category (e.g. for a family, this would be the
   order).

``"seq"``
   Only present in the deepest nodes (e.g. species), and is an array of
   the sequences that are in the input dataset that are in the given
   species. Each element of the array is a hash ref that stores the
   UniProt (``"sa"``), UniRef50 (``"sa50"``), and UniRef90 ``"sa90"``
   IDs.



Example Usage
^^^^^^^^^^^^^

::

   # $sequenceIdData comes from a script, e.g. filter_ids.pl
   my $data = $sb->getSunburstTaxonomy($sequenceIdData);
   my $json = encode_json($data);
   # save $json to file

Example output:

::

   {
     "data": {
       "children": [
         {
           "children": [
             {
               "children": [
                 {
                   "children": [
                     {
                       "children": [
                         {
                           "children": [
                             {
                               "children": [
                                 {
                                   "children": [
                                     {
                                       "d": 8,
                                       "id": 1714,
                                       "node": "Anaerolineales bacterium",
                                       "nq": 3,
                                       "ns": 1,
                                       "parent": "NA",
                                       "seq": [
                                         {
                                           "sa": "A0A957HU66",
                                           "sa50": "A0A957HU66",
                                           "sa90": "A0A957HU66"
                                         },
                                         {
                                           "sa": "A0A957GT41",
                                           "sa50": "A0A957GT41",
                                           "sa90": "A0A957GT41"
                                         },
                                         {
                                           "sa": "A0A957F8D3",
                                           "sa50": "A0A957F8D3",
                                           "sa90": "A0A957F8D3"
                                         }
                                       ]
                                     }
                                   ],
                                   "d": 7,
                                   "id": 1713,
                                   "node": "NA",
                                   "nq": 3,
                                   "ns": 1,
                                   "parent": "unclassified Anaerolineal"
                                 }
                               ],
                               "d": 6,
                               "id": 1712,
                               "node": "unclassified Anaerolineal",
                               "nq": 3,
                               "ns": 1,
                               "parent": "Anaerolineales"
                             },
                             {
                               "children": [
                                 {
                                   "children": [
                                     {
                                       "d": 8,
                                       "id": 1717,
                                       "node": "Anaerolineaceae bacterium oral taxon 439",
                                       "nq": 1,
                                       "ns": 1,
                                       "parent": "unclassified Anaerolineaceae",
                                       "seq": [
                                         {
                                           "sa": "A0A1B3WQ01",
                                           "sa50": "Q3AEU2",
                                           "sa90": "A0A1B3WQ01"
                                         }
                                       ]
                                     }
                                   ],
                                   "d": 7,
                                   "id": 1716,
                                   "node": "unclassified Anaerolineaceae",
                                   "nq": 1,
                                   "ns": 1,
                                   "parent": "Anaerolineaceae"
                                 }
                               ],
                               "d": 6,
                               "id": 1715,
                               "node": "Anaerolineaceae",
                               "nq": 1,
                               "ns": 1,
                               "parent": "Anaerolineales"
                             }
                           ],
                           "d": 5,
                           "id": 1711,
                           "node": "Anaerolineales",
                           "nq": 4,
                           "ns": 2,
                           "parent": "Anaerolineae"
                         }
                       ],
                       "d": 4,
                       "id": 1705,
                       "node": "Anaerolineae",
                       "nq": 4,
                       "ns": 2,
                       "parent": "Chloroflexota"
                     }
                   ],
                   "d": 3,
                   "id": 1674,
                   "node": "Chloroflexota",
                   "nq": 4,
                   "ns": 2,
                   "parent": "Bacillati"
                 },
               ],
               "d": 2,
               "id": 1095,
               "node": "Bacillati",
               "nq": 4,
               "ns": 2,
               "parent": "Bacteria"
             },
           ],
           "d": 1,
           "id": 321,
           "node": "Bacteria",
           "nq": 4,
           "ns": 2
         }
       ],
       "d": 0,
       "id": 0,
       "node": "Root",
       "nq": 4,
       "ns": 2
     }
   }
