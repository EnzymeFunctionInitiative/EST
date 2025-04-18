XgmmlReader.pm
==============

Reference
---------


EFI::SSN::XgmmlReader
=====================



NAME
----

EFI::SSN::XgmmlReader - Perl utility module for extracting network
information from XGMML files



SYNOPSIS
--------

::

   use EFI::SSN::XgmmlReader;

   my $parser = EFI::SSN::XgmmlReader->new(xgmml_file => $ssnFile);
   $parser->parse();

   my $edgelist = $parser->getEdgeList();
   my $indexSeqIdMap = $parser->getIndexSeqIdMap();
   my $idIndexMap = $parser->getIdIndexMap();

   map { print join(" ", @$_), "\n"; } @$edgelist;
   map { print join("\t", $_, $indexSeqIdMap->{$_}), "\n"; } keys %$indexSeqIdMap;
   map { print join("\t", $_, $idIndexMap->{$_}), "\n"; } sort keys %$idIndexMap;



DESCRIPTION
-----------

**EFI::SSN::XgmmlReader** is a Perl module for parsing XGMML (XML
format) files. Data that is saved includes an edgelist, node indices,
node IDs, and sequence IDs. SSN nodes are given an index number
(numerical) in the order in which they appear in the file. The edgelist
is composed of a pair of node indices. In addition to node indicies,
nodes also contain sequence IDs which are defined by the ``label``
attribute in a SSN ``node`` element. Node IDs may or may not be the same
as the sequence ID; the EFI tools output SSN files with the ``id`` and
``label`` attribute containing the same value, but XGMML tools such as
Cytoscape may not preserve that and will rather create their own node ID
(stored in the ``id`` attribute).



METHODS
-------



``new(xgmml_file => $ssnFile)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::SSN::XgmmlReader** object.



Parameters
^^^^^^^^^^

``xgmml_file``
   Path to a SSN file in XGMML format (XML).



Returns
^^^^^^^

Returns an object.



Example Usage
^^^^^^^^^^^^^

::

   my $parser = EFI::SSN::XgmmlReader->new(xgmml_file => $ssnFile);

``parse()``
~~~~~~~~~~~

Parses the XGMML file on a per-element basis. This method doesn't create
a DOM; rather it obtains information from each XML element as the file
is being parsed and builds an internal representation of an SSN as a
collection of arrays and hashes.



Example Usage
^^^^^^^^^^^^^

::

   $parser->parse();



``getEdgeList()``
~~~~~~~~~~~~~~~~~

Gets the edgelist, which is a list of edges where each edge is defined
as a pair of node indices.



Returns
^^^^^^^

An array ref with each element being a two-element array ref of the
source and target node indices.



Example Usage
^^^^^^^^^^^^^

::

   my $edgelist = $parser->getEdgeList();
   map { print join(" ", @$_), "\n"; } @$edgelist;



``getIndexSeqIdMap()``
~~~~~~~~~~~~~~~~~~~~~~

Gets the structure that correlates node index to sequence ID.



Returns
^^^^^^^

A hash ref that maps node index to sequence ID (numeric -> string).



Example Usage
^^^^^^^^^^^^^

::

   my $indexSeqIdMap = $parser->getIndexSeqIdMap();
   map { print join("\t", $_, $indexSeqIdMap->{$_}), "\n"; } keys %$indexSeqIdMap;



``getIdIndexMap()``
~~~~~~~~~~~~~~~~~~~

Gets a mapping of node IDs (the ``id`` attribute in a SSN node) to node
index.



Returns
^^^^^^^

A hash ref mapping node ID (string) to node index (numeric)



Example Usage
^^^^^^^^^^^^^

::

   my $idIndexMap = $parser->getIdIndexMap();
   map { print join("\t", $_, $idIndexMap->{$_}), "\n"; } sort keys %$idIndexMap;
