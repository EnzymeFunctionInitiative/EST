IdList.pm
=========

Reference
---------


EFI::SSN::XgmmlReader::IdList
=============================



NAME
----

EFI::SSN::XgmmlReader::IdList - Perl utility module for extracting
network and metanode information from XGMML files



SYNOPSIS
--------

::

   use EFI::SSN::XgmmlReader::IdList;

   my $parser = EFI::SSN::XgmmlReader::IdList->new(xgmml_file => $ssnFile);
   $parser->parse();

   my $metanodeType = $parser->getMetanodeType();
   my $metanodeSizes = $parser->getMetanodeSizes();
   my $metanodeMap = $parser->getMetanodes();
   print "Network ID type: $metanodeType\n"; # uniprot, uniref90, uniref50, repnode
   if ($metanodeType ne "uniprot") {
       foreach my $metanode (sort keys %$metanodeMap) {
           map {
               print join("\t", $metanode,
                                $metanodeSizes->{$_},
                                $_);
               print "\n";
           } @{ $metanodeMap->{$metanode} };
       }
   }



DESCRIPTION
-----------

**EFI::SSN::XgmmlReader::IdList** is a Perl module for parsing XGMML
(XML format files). It extends the functionality of
**EFI::SSN::XgmmlReader** by additionally parsing metanode identifying
information from the network; metanodes are SSN nodes that represent
multiple sequences. There are two types: UniRef and RepNode metanodes.
This module also retains information that maps a metanode ID (sequence
ID) to the sequence IDs inside the ID. The metanode ID is correlated to
the node index. **EFI::Annotations** is used to get a list of SSN field
names that represent metanode ID data, which determine which node
attribute is being processed. See **EFI::SSN::XgmmlReader** for methods
for parsing and obtaining network information



METHODS
-------



``getMetanodeType()``
~~~~~~~~~~~~~~~~~~~~~

Gets the type of the metanodes in the network.



Returns
^^^^^^^

One of ``uniprot``, ``uniref90``, ``uniref50``, ``repnode``



Example Usage
^^^^^^^^^^^^^

::

   my $metanodeType = $parser->getMetanodeType();
   print "Network ID type: $metanodeType\n"; # uniprot, uniref90, uniref50, repnode



``getMetanodeSizes()``
~~~~~~~~~~~~~~~~~~~~~~

Gets the sizes of the metanodes in the network.



Returns
^^^^^^^

A hash ref that maps metanode sequence ID to the number of sequences
contained in the metanode. If the network is a UniProt network then this
hash is empty.



Example Usage
^^^^^^^^^^^^^

::

   my $metanodeSizes = $parser->getMetanodeSizes();



``getMetanodes()``
~~~~~~~~~~~~~~~~~~

Gets metanodes from the network.



Returns
^^^^^^^

A hash ref that maps metanode sequence ID (the metanode is the XGMML
node in the SSN) to a list of sequence IDs that the metanode represents.
If the network is a UniProt network then this hash is empty.



Example Usage
^^^^^^^^^^^^^

::

   my $metanodeMap = $parser->getMetanodes();
   foreach my $metanode (sort keys %$metanodeMap) {
       map { print join("\t", $metanode, $_), "\n"; } @{ $metanodeMap->{$metanode} };
   }



``getMetadata()``
~~~~~~~~~~~~~~~~~

Gets the metadata (node attributes) that is saved during parsing
(currently only SwissProt description). This is primarily used in the
case that the network is UniProt; in that case the EFI database is not
queried to obtain metadata information. If the network is UniRef, then
the database is queried and the SwissProt information from the queries
is used instead of the saved node attribute.



Returns
^^^^^^^

A hash ref with keys being the sequence ID (metanode ID), with each
value being another hash ref with each saved node attribute. Currently
the ``swissprot`` and ``sequence`` hash ref keys are supported. Only
sequence IDs with attribute values are in the hash ref. The ``sequence``
key will only be present if a protein sequence was included; this is
used when unidentified sequences are included in the analysis.

::

   {
       "UNIPROT_ID" => {
           "swissprot" => "Description",
           "sequence" => "ABC"
       },
       "UNIPROT_ID2" => {},
       "UNIPROT_ID3" => {
           "swissprot" => "Description"
       }
   }



Example Usage
^^^^^^^^^^^^^

::

   my $metadata = $parser->getMetadata();
   foreach my $id (keys %$metadata) {
       foreach my $md (keys %{ $metadata->{$id} }) {
           print "$id\t$md\t$metadata->{$id}->{$md}\n";
       }
   }
