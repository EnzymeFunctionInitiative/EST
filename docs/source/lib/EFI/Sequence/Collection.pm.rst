Collection.pm
=============

Reference
---------


EFI::Sequence::Collection
=========================



NAME
----

**EFI::Sequence::Collection** - Perl module that represents a collection
of sequences and metadata



SYNOPSIS
--------

::

   use EFI::Sequence;
   use EFI::Sequence::Collection;
   use EFI::Sequence::Type;

   my $seqSource = SEQ_UNIREF50;
   my $mdFile = "sequence_metadata.tab";
   my $idFile = "accession_table.tab";

   $seqs->load($mdFile, $idFile, sequence_source => $seqSource);

   $seqs->addSequence("B0SS77", {}, "");

   $seqs->addUniref("A0AAQ2CWD6", "B0SS77", "B0SS77");
   print $seqs->getUniref90Id("A0AAQ2CWD6"), "\n";
   print $seqs->getUniref50Id("A0AAQ2CWD6"), "\n";

   my @ids = $seqs->getSequenceIds();
   my $seq = $seqs->getSequence("B0SS77");

   $seqs->removeSequence("A0AAQ2CWD6"); # removes only from ID list
   $seqs->removeSequence("B0SS77"); # removes all UniProt IDs in the UniRef50 cluster

   # Update the UniRef metadata
   $seqs->updateUnirefMetadata();

   $seqs->save($mdFile, $idFile);
   $seqs->save("$mdFile.2");



DESCRIPTION
-----------

**EFI::Sequence** is a Perl module used to represent a sequence from the
EFI database with the sequence and attributes.



METHODS
-------



``getFields()``
~~~~~~~~~~~~~~~

Return a list of all of the metadata fields in the metadata file that
was loaded. These typically match those in **EFI::Annotations::Fields**.
Not all sequences may have all of the same fields.



Returns
^^^^^^^

An array ref containing all of the metadata fields in the file.



Example Usage
^^^^^^^^^^^^^

::

   my $fields = $seqs->getFields();
   map { print "Field $_\n"; } @$fields;



``addSequence($id, $attr, $seq)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Add a sequence to the collection. Optionally add attributes (``$attr``
in the form of a hash ref) and a protein sequence ``$seq`` as metadata.



Parameters
^^^^^^^^^^

``$id``
   The UniProt sequence identifier.

``$attr``
   A hash ref mapping metadata fields to values for the sequence ID.

``$seq`` (optional)
   The protein amino acid sequence for the sequence.



Example Usage
^^^^^^^^^^^^^

::

   my $id = "B0SS77";
   my $attr = {
       &FIELD_SPECIES => "Leptospira biflexa serovar Patoc (strain Patoc 1 / ATCC 23582 / Paris)",
       &FIELD_SWISSPROT_DESC => "D-alanine--D-alanine ligase",
       &FIELD_UNIREF90_CLUSTER_SIZE => 3,
       &FIELD_UNIREF90_IDS => "B0S9U5^A0AAQ2CWD6^B0SS77",
       "custom" => "value"
   };
   my $seq = "MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYP";
   $seqs->addSequence($id, $attr, $seq);



``addUniref($uniprot, $uniref90, $uniref50)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Adds a new mapping of UniProt ID to associated UniRef sequence IDs to
the ID list/mapping. This mapping will likely be a superset of the IDs
added with the ``addSequence()`` function in order to support sunburst
diagrams for UniRef jobs (since all of the IDs are necessary, not just
UniRef).



Parameters
^^^^^^^^^^

``$uniprot``
   The UniProt ID.

``$uniref90``
   The UniRef90 ID for the UniProt ID. This may be blank in which case
   there is no associated UniRef90 ID (or the UniRef90 ID is not in the
   same family as the UniProt ID).

``$uniref50``
   The UniRef50 ID for the UniProt ID. This may be blank in which case
   there is no associated UniRef50 ID (or the UniRef50 ID is not in the
   same family as the UniProt ID).



Example Usage
^^^^^^^^^^^^^

::

   $seqs->addUniref("A0AAQ2CWD6", "B0SS77", "B0SS77");
   print $seqs->getUniref90Id("A0AAQ2CWD6"), "\n"; # "B0SS77"
   print $seqs->getUniref50Id("A0AAQ2CWD6"), "\n"; # "B0SS77"



``getUniref90Id($uniprotId)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Retrieves the UniRef90 ID for the given UniProt ID. It may be that there
is no UniRef90 ID in which case an empty string is returned.



Parameters
^^^^^^^^^^

``$uniprotID``
   The UniProt ID to retrieve the UniRef90 ID for.



Returns
^^^^^^^

A UniRef90 ID.



Example Usage
^^^^^^^^^^^^^

::

   $seqs->addUniref("A0AAQ2CWD6", "B0SS77", "B0SS77");
   print $seqs->getUniref90Id("A0AAQ2CWD6"), "\n"; # "B0SS77"



``getUniref50Id($uniprotId)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Retrieves the UniRef50 ID for the given UniProt ID. It may be that there
is no UniRef50 ID in which case an empty string is returned.



Parameters
^^^^^^^^^^

``$uniprotId``
   The UniProt ID to retrieve the UniRef50 ID for.



Returns
^^^^^^^

A UniRef50 ID.



Example Usage
^^^^^^^^^^^^^

::

   $seqs->addUniref("A0AAQ2CWD6", "B0SS77", "B0SS77");
   print $seqs->getUniref50Id("A0AAQ2CWD6"), "\n"; # "B0SS77"



``getSequence($uniprotId)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Retrieve the protein amino acid sequence for the given UniProt ID.
Returns an empty string if there is no sequence associated with the ID.



Parameters
^^^^^^^^^^

``$uniprotId``
   The UniProt ID of the sequence to be retrieved.



Returns
^^^^^^^

Amino acid sequence as a string, empty if there is no sequence.



Example Usage
^^^^^^^^^^^^^

::

   my $seq = $seqs->getSequence("B0SS77");
   # $seq should be something like "MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYP"



``getSequenceIds()``
~~~~~~~~~~~~~~~~~~~~

Retrieve all of the sequence IDs in the input metadata file (i.e. not
the ID list file). If the input dataset originates from UniProt, then
the IDs are all UniProt. Otherwise the IDs are UniRef.



Returns
^^^^^^^

In scalar context, an array ref of a list of all of the sequence IDs. In
list context, a list of all of the sequence IDs.



Example Usage
^^^^^^^^^^^^^

::

   my $ids = $seqs->getSequenceIds();
   map { print "ID1 $_\n"; } @$ids;

   my @ids = $seqs->getSequenceIds();
   map { print "ID2 $_\n"; } @ids;



``removeSequence($sequenceId)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Remove the sequence ID from the input metadata set if it is a primary
sequence. Also remove the sequence ID from the ID list tables. In the
latter case, if the input dataset originates from UniRef IDs and the
``$sequenceId`` is a UniRef ID, then all of the members of the UniRef
cluster are also removed. A few examples are given:

**Example 1: Input Originating in UniProt**

::

   # Initial metadata 
   #UniProt_ID      Attribute       Value
   #A0A8J3V1H9      Sequence_Source FAMILY
   #
   # Initial ID list 
   #uniprot_id uniref90_id     uniref50_id
   #A0A8J3TPF4 A0A8J3V1H9      Q3AEU2
   #A0A8J3V1H9 A0A8J3V1H9      Q3AEU2

   $seqs->removeSequence("A0A8J3TPF4");

   # Metadata after removal
   #UniProt_ID      Attribute       Value
   #A0A8J3V1H9      Sequence_Source FAMILY
   #
   # ID list after removal
   #uniprot_id uniref90_id     uniref50_id
   #A0A8J3V1H9 A0A8J3V1H9      Q3AEU2

**Example 2: Input Originating in UniProt (2)**

::

   # Initial metadata 
   #UniProt_ID      Attribute       Value
   #A0A8J3V1H9      Sequence_Source FAMILY
   #
   # Initial ID list 
   #uniprot_id uniref90_id     uniref50_id
   #A0A8J3TPF4 A0A8J3V1H9      Q3AEU2
   #A0A8J3V1H9 A0A8J3V1H9      Q3AEU2

   $seqs->removeSequence("A0A8J3V1H9");

   # Metadata after removal
   #UniProt_ID      Attribute       Value
   #
   # ID list after removal
   #uniprot_id uniref90_id     uniref50_id
   #A0A8J3TPF4 A0A8J3V1H9      Q3AEU2

**Example 3: Input Originating in UniRef50**

::

   # Initial metadata 
   #UniProt_ID      Attribute       Value
   #Q3AEU2     Sequence_Source FAMILY
   #Q3AEU2     UniRef50_Cluster_Size   2
   #Q3AEU2     UniRef50_IDs    A0A8J3TPF4^A0A8J3V1H9
   #
   # Initial ID list 
   #uniprot_id uniref90_id     uniref50_id
   #A0A8J3TPF4 A0A8J3V1H9      Q3AEU2
   #A0A8J3V1H9 A0A8J3V1H9      Q3AEU2

   $seqs->removeSequence("A0A8J3TPF4");

   # Metadata after removal
   #UniProt_ID      Attribute       Value
   #Q3AEU2     Sequence_Source FAMILY
   #Q3AEU2     UniRef50_Cluster_Size   2
   #Q3AEU2     UniRef50_IDs    A0A8J3V1H9
   #
   # ID list after removal
   #uniprot_id uniref90_id     uniref50_id
   #A0A8J3V1H9 A0A8J3V1H9      Q3AEU2

**Example 4: Input Originating in UniRef50 (2)**

::

   # Initial metadata 
   #UniProt_ID      Attribute       Value
   #Q3AEU2     Sequence_Source FAMILY
   #
   # Initial ID list 
   #uniprot_id uniref90_id     uniref50_id
   #A0A8J3TPF4 A0A8J3V1H9      Q3AEU2
   #A0A8J3V1H9 A0A8J3V1H9      Q3AEU2

   $seqs->removeSequence("Q3AEU2");

   # Metadata after removal
   #UniProt_ID      Attribute       Value
   #
   # ID list after removal
   #uniprot_id uniref90_id     uniref50_id



``updateUnirefMetadata()``
~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates or updates the UniRef-related metadata fields in the sequence
metadata file. For a UniRef90 sequence source these fields are
``UniRef90_Cluster_Size`` which represents the number of UniProt IDs in
the UniRef90 cluster, and ``UniRef50_IDs`` which represents the IDs in
the UniRef50 cluster. (These are stored as a text string with each ID
separated by the caret ``^`` character.) This information comes from the
ID list.



Example Usage
^^^^^^^^^^^^^

::

   #$seqs->addSequence(), addUniref(), etc
   $seqs->updateUnirefMetadata();
   # save



``load($metadataFile, $idFile, sequence_source => source)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Loads metadata and ID lists from files. See ``save()`` for the file
format.



Parameters
^^^^^^^^^^

``$metadataFile``
   Path to metadata file (e.g. "sequence_metadata.tab").

``$idFile``
   Path to ID list file (e.g. "accession_table.tab"). If specified, load
   the ID mapping, otherwise only metadata is loaded.

``sequence_source`` (optional)
   If specified, used instead of sequence source defined at object
   creation. One of ``SEQ_UNIPROT``, ``SEQ_UNIREF90``, or
   ``SEQ_UNIREF50`` from **EFI::Sequence::Type**.



Returns
^^^^^^^

1 upon success, 0 otherwise.



Example Usage
^^^^^^^^^^^^^

::

   my $seqSource = SEQ_UNIREF50;
   my $retval = $seqs->load($mdFile, $idFile, sequence_source => $seqSource);
   die "Unable to load $mdFile, $idFile" if not $retval;



``save($metadataFile, $idFile)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Saves the metadata and ID lists. The metadata file contains a mapping of
keys and values for attributes for each sequence ID. The ID list file
contains a mapping of UniProt and UniRef IDs. The IDs in the ID list may
be a superset of the IDs in the metadata file; this will occur when the
input data set originates from a UniRef source, and the ID list must
contain a mapping of UniProt to UniRef for future steps (e.g. filtering
and sunburst diagrams).



Parameters
^^^^^^^^^^

``$metadataFile``
   Path to metadata file (e.g. "sequence_metadata.tab").

``$idFile`` (optional)
   Path to ID list file (e.g. "accession_table.tab"). If specified, save
   the ID mapping, otherwise only metadata is saved.



Example Usage
^^^^^^^^^^^^^

::

   # $mdFile, $idFile are set in previous steps
   $seqs->save($mdFile, $idFile);

   # $mdFile will contain something like:
   #
   #UniProt_ID      Attribute       Value
   #A0A8J3V1H9      Sequence_Source FAMILY
   #A0A8J3V1H9      UniRef90_Cluster_Size   2
   #A0A8J3V1H9      UniRef90_IDs    A0A8J3TPF4^A0A8J3V1H9

   # $idFile will contain something like:
   #
   #uniprot_id uniref90_id     uniref50_id
   #A0A8J3TPF4 A0A8J3V1H9      Q3AEU2
   #A0A8J3V1H9 A0A8J3V1H9      Q3AEU2



``updateUnirefMetadata()``
~~~~~~~~~~~~~~~~~~~~~~~~~~

Add the internal UniRef ID mapping to the sequence metadata so that the
sequence metadata file (e.g. sequence_metadata.tab) contains the proper
UniRef data.



Example Usage
^^^^^^^^^^^^^

::

   $seqs->updateUnirefMetadata();



``new($id, attr => $attr, seq => $seq)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::Sequence** instance with the ID ``$id``, attributes
stored in ``$attr``, and sequence stored in ``$seq``.



Parameters
^^^^^^^^^^

``$id``
   UniProt sequence identifier.

``attr``
   Optional attributes, as a hash ref.

``seq``
   Optional protein sequence as a string.



Example Usage
^^^^^^^^^^^^^

::

   my $seq = new EFI::Sequence($id, attr => $attr, sequence => $fastaSeq);



``getId()``
~~~~~~~~~~~

Get the sequence identifier.



Returns
^^^^^^^

Sequence identifier as a string.



Example Usage
^^^^^^^^^^^^^

::

   my $id = $seq->getId();



``getAttribute($name)``
~~~~~~~~~~~~~~~~~~~~~~~

Gets the value of the attribute with the given name.



Parameters
^^^^^^^^^^

``$name``
   Attribute name; typically one from the available options in
   **EFI::Annotations::Fields**.



Returns
^^^^^^^

The attribute value as a string (packed if the value is a list).



Example Usage
^^^^^^^^^^^^^

::

   $seq->setAttribute("list1", ["item 1", "item 2", "item 3"]);
   my $val = $seq->getAttribute("list1");
   # $val is: "item 1^item 2^item 3"



``getAttributeNames()``
~~~~~~~~~~~~~~~~~~~~~~~

Gets the list of available attribute names for the sequence.



Returns
^^^^^^^

Returns an array of attribute names in array context. Returns an array
ref of attribute names in scalar context.



Example Usage
^^^^^^^^^^^^^

::

   my @names = $seq->getAttributeNames();
   print "Available attributes: " . join(", ", @names) . "\n";

   my $names = $seq->getAttributeNames();
   print "Available attributes: " . join(", ", @$names) . "\n";



``setAttribute($name, $value)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Sets the attribute value for the given attribute name.



Parameters
^^^^^^^^^^

``$name``
   Attribute name; typically one from the available options in
   **EFI::Annotations::Fields**, although can be anything.

``$value``
   Scalar, array, or array ref.



Example Usage
^^^^^^^^^^^^^

::

   $seq->setAttribute("custom", "value");
   $val = $seq->getAttribute("custom");
   # $val is "value"

   $seq->setAttribute("list1", ["item 1", "item 2", "item 3"]);
   $val = $seq->getAttribute("list1");
   # $val is: "item 1^item 2^item 3"

   $seq->setAttribute("list2", "item 1", "item 2", "item 3");
   $val = $seq->getAttribute("list1");
   # $val is: "item 1^item 2^item 3"



``packAttributeValue($value)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Packs the attribute value into a string that can be serialized and
deserialized. Elements in packed arrays are separated by the caret
character (``^``).



Parameters
^^^^^^^^^^

``$value``
   Value to pack, either a scalar or an array ref.



Returns
^^^^^^^

Returns ``$value`` if scalar. Returns packed array if ``$value`` is an
array ref.



Example Usage
^^^^^^^^^^^^^

::

   $val = $seq->packAttributeValue("value");
   # $val is "value"
   $val = $seq->packAttributeValue(["item 1", "item 2", "item 3"]);
   # $val is: "item 1^item 2^item 3"
