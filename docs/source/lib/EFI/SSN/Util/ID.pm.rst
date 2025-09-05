ID.pm
=====

Reference
---------


EFI::SSN::Util::ID
==================



NAME
----

EFI::SSN::Util::ID - Perl module for parsing and performing various
sequence ID-related actions.



SYNOPSIS
--------

::

   use EFI::SSN::Util::ID qw(resolve_mapping parse_cluster_map_file get_cluster_num_cols parse_metanode_map_file);

   # $clusterMapFile comes from another utility, the Python `compute_clusters.py` script
   my ($seqClusterToId, $nodeClusterToId) = parse_cluster_map_file($clusterMapFile);

   # $metanodeMapFile comes from another utility, ssn_to_id_list.pl
   my ($idType, $sourceIdMap) = parse_metanode_map_file($metanodeMapFile);

   my $newClusterToId = resolve_mapping($seqClusterToId, $idType, $sourceIdMap);

   # $header = "node_label      cluster_num_by_seq      cluster_num_by_node"
   my ($seqNumCol, $nodeNumCol) = get_cluster_num_cols($header);



DESCRIPTION
-----------

**EFI::SSN::Util::ID** is a utility module that provides functions to
parse and manipulate files and structures that contain sequence ID
information such as cluster number to IDs and metanodes. A metanode is a
node in the network that represents one or more sequences. For example,
networks generated using UniRef will contain nodes that correspond to
UniRef sequences, which in turn represent one or more UniProt sequences.
Additionally, metanodes can represent multiple sequences that are
grouped together in repnode networks to reduce the size of the network.
Clusters can be numbered by sequence or by node; by-sequence numbering
takes into account all of the sequences in all of the metanodes in the
cluster (effectively expanding the metanode), whereas by-node numbering
uses only the metanodes in the cluster. For UniProt networks metanodes
are simply normal nodes and by-sequence and by-node numbering is
identical.



METHODS
-------



``parse_cluster_map_file($clusterMapFile)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Parses a file that contains a mapping of sequence IDs to cluster
numbers.



Parameters
^^^^^^^^^^

``$clusterMapFile``
   A file that contains three columns; the first column being the
   sequence ID, with the second and third columns being the cluster
   numbers (by sequence and by node). If the cluster number columns
   don't exist then the singleton number ('0') is assigned.



Returns
^^^^^^^

``$seqClusterToId``
   A hash ref that maps cluster numbers to an array of sequence IDs
   within that cluster. The clusters that are returned are numbered by
   sequence (e.g. the ``cluster_num_seq`` column in the input file). For
   example, a repnode network that contains cluster 1 with a metanode
   ``"REPNODE_ID1"`` that represents ``"UNIPROT_ID1"`` and
   ``"UNIPROT_ID2"``), and cluster 2 with a metanode ``"REPNODE_ID2"``
   that represents ``"UNIPROT_ID3"`` as well as a single node
   ``"REPNODE_ID3"`` would look like:

   ::

      {
          1 => ["UNIPROT_ID1", "UNIPROT_ID2", "REPNODE_ID1", ...],
          2 => ["UNIPROT_ID3", "REPNODE_ID2", "REPNODE_ID3", ...],
          ...
      }

``$nodeClusterToId``
   A hash ref that maps cluster numbers to an array of sequence IDs
   within that cluster. The clusters that are returned are numbered by
   node/metanode (e.g. the ``cluster_num_node`` column in the input
   file). In the example given above (the ``$seqClusterToId`` return
   value), the output would look like:

   ::

      {
          1 => ["REPNODE_ID1", ...],
          2 => ["REPNODE_ID2", "REPNODE_ID3", ...],
          ...
      }



Example Usage
^^^^^^^^^^^^^

::

   my ($seqClusterToId, $nodeClusterToId) = parse_cluster_map_file($clusterMapFile);



``parse_metanode_map_file($metanodeMapFile)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Parses a file that contains a mapping of metanodes to nodes within the
metanode. The result may be an empty hash ref in the case that the file
is empty (which occurs when the input to the pipeline is a UniProt
network). Metanodes are simply sequence IDs that represent multiple
sequences. There may only be an one-to-one mapping in which case the
metanode represents itself (equivalent to a UniProt ID).



Parameters
^^^^^^^^^^

``$metanodeMapFile``
   A tab-separated file with a header where the first column is the
   metanode and the second column is the sequence within the metanode.



Returns
^^^^^^^

A hash ref that maps metanode to a list of sequences. For example:

::

   {
       "UNIPROT_ID1" => ["UNIPROT_ID1"],
       "METANODE_ID1" => ["UNIPROT_ID9", "UNIPROT_ID10", ...],
       "METANODE_ID2" => ["UNIPROT_ID20", "UNIPROT_ID30", ...],
       "METANODE_ID3" => ["UNIPROT_ID7"],
       ...
   }



Example Usage
^^^^^^^^^^^^^

::

   # $metanodeMapFile comes from another utility, ssn_to_id_list.pl
   my ($idType, $sourceIdMap) = parse_metanode_map_file($metanodeMapFile);



``resolve_mapping($clusterToId, $idType, $sourceIdMap)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Expands any metanode IDs in the ``$clusterToId`` data structure to the
full set of sequences. For example, if cluster 1 contains 5 metanodes,
with each one containing 3 sequences, the structure returned will have
cluster 1 with 15 sequences rather than the 5 metanodes.

A metanode is a node that represents other nodes, i.e. RepNodes
(representative nodes that cluster together sequences based on some
percent identity) and UniRef IDs (which cluster sequences together based
on sequence similarity). Metanodes take the same format as sequence IDs
since they are actually a sequence ID that represents other sequences.



Parameters
^^^^^^^^^^

``$clusterToId``
   A hash ref that maps cluster number to lists of sequence IDs (which
   may be metanodes).

   ::

      {
          1 => ["UNIPROT_ID1", "UNIPROT_ID2", "METANODE_ID1", ...],
          2 => ["UNIPROT_ID3", "METANODE_ID2", "METANODE_ID3", ...],
          ...
      }

``$idType``
   A string that specifies the type of IDs in the ``$sourceIdMap``
   parameter. It can be ``uniref90``, ``uniref50``, ``repnode``, and
   ``uniprot``. If it is empty or undefined, the input is assumed to be
   UniProt sequences and the output of the function will be the same as
   the input ``$clusterToId``.

``$sourceIdMap``
   A hash ref that maps metanode IDs to sequence IDs in the metanode. If
   this is empty or undefined, the input is assumed to be UniProt
   sequences and the output of the function will be the same as the
   input ``$clusterToId``. If an ID in ``$clusterToId`` is not present
   in the mapping then that ID is assumed to be a UniProt ID.

   ::

      {
          "UNIPROT_ID1" => ["UNIPROT_ID1"],
          "METANODE_ID1" => ["UNIPROT_ID9", "UNIPROT_ID10", ...],
          "METANODE_ID2" => ["UNIPROT_ID20", "UNIPROT_ID30", ...],
          "METANODE_ID3" => ["UNIPROT_ID7"],
          ...
      }



Returns
^^^^^^^

Returns a hash ref that maps cluster number to the full list of IDs
(expanded from the metanode).

::

   {
       1 => ["UNIPROT_ID1", "UNIPROT_ID9", "UNIPROT_ID10", ...],
       2 => ["UNIPROT_ID3", "UNIPROT_ID20", "UNIPROT_ID30", ...],
       ...
   }



Example Usage
^^^^^^^^^^^^^

::

   my $clusterToId = {}; # get the mapping somehow
   my $sourceIdMap = {}; # get the mapping somehow
   my $newMapping = resolve_mapping($clusterToId, "repnode", $sourceIdMap);

   foreach my $clusterNum (keys %$newMapping) {
       foreach my $id (@{ $newMapping->{$clusterNum} }) {
           print "$clusterNum\t$id\n";
       }
   }



``get_cluster_num_cols($header)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Returns the column index of the cluster number by sequence and by node
in ``cluster_id_map`` files. These are used when parsing rows in the
file to extract the sequence cluster number.



Parameters
^^^^^^^^^^

A tab-separated 2-3 column header line. For example:

::

   # $header = "node_label      cluster_num_by_seq      cluster_num_by_node"



Returns
^^^^^^^

$seqNumCol
   The column index of the clusters numbered by sequence.

$nodeNumCol
   The column index of the clusters numbered by nodes.



Example Usage
^^^^^^^^^^^^^

::

   my ($seqNumCol, $nodeNumCol) = get_cluster_num_cols($header);
   chomp(my $row = getLine());
   my @p = split(m/\t/, $row);
   my $clusterNum = $p[$seqNumCol];
