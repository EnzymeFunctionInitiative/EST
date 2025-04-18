ssn_to_id_list
==============
Usage
-----

::

	Usage: perl pipelines/shared/perl/ssn_to_id_list.pl --ssn <FILE> --edgelist <FILE>
	    --index-seqid <FILE> --id-index <FILE> --seqid-source-map <FILE> [--ssn-sequences <VALUE>]
	
	Description:
	    Parses an XGMML file to retrieve an edgelist and mapping info
	
	Options:
	    --ssn                 path to XGMML (XML) SSN file
	    --edgelist            path to an output edgelist file (two column space-separated file)
	    --index-seqid         path to an output file mapping node index to XGMML nodeseqid (and optionally node size for UniRef/repnodes)
	    --id-index            path to an output file mapping XGMML node ID to node index
	    --seqid-source-map    path to an output file for mapping metanodes (e.g. RepNode or UniRef node) to UniProt nodes [optional]; the file is created regardless, but if the input IDs are UniProt the file is empty
	    --ssn-sequences       optional path to an output FASTA file for saving sequences that were embedded in the SSN

Reference
---------


NAME
----

``ssn_to_id_list.pl`` - gets network information from a SSN



SYNOPSIS
--------

::

   ssn_to_id_list.pl --ssn <FILE> --edgelist <FILE> --index-seqid <FILE>
       --id-index <FILE> --seqid-source-map <FILE> [--ssn-sequences <FILE>]



DESCRIPTION
-----------

``ssn_to_id_list.pl`` parses a SSN and gets the network connectivity and
ID mappings that are in the SSN. Nodes are assigned an index value as
they are encountered in the file. Additionally, the node ID (which may
differ from the sequence ID) is obtained and stored, as is the sequence
ID (from the node ``label`` field).



Arguments
~~~~~~~~~

``--ssn``
   Path to the input SSN uploaded by the user.

``--edgelist``
   Path to the output edgelist, consisting of space separated pairs of
   node indices. There is no header. For example:

   ::

      1 2
      1 8
      3 8

``--index-seqid``
   Path to a tab-separated output file that contains a mapping of node
   index to sequence ID and metanode size. The sequence ID comes from
   the ``label`` field in nodes. The third column is ``node_size``
   representing the metanode (e.g. UniRef or RepNode network) size; for
   UniProt SSNs this will always be 1. An example file:

   ::

      node_index node_seqid node_size
      1 B0SS77 2
      3 B0SS75 1

``--id-index``
   Path to a tab-separated output file that maps node ID (the ``id``
   attribute in a node) to node index. The ``id`` attribute may not be
   the same as the ``label`` attribute; the latter is the sequence ID.
   For example:

   ::

      node_id node_index
      id1 1
      id2 3

``--seqid-source-map``
   Path to a tab-separated output file that maps metanodes (e.g.
   RepNodes or UniRef nodes) that are in the SSN to sequence IDs that
   are within the metanode. For example, if the input SSN has UniRef90
   IDs, this file might look something like this:

   ::

      uniref90_id uniprot_id
      B0SS77 UNIPROT1
      B0SS77 UNIPROT2
      B0SS75 UNIPROT3

``--ssn-sequences``
   Optional path to an output FASTA file that contains sequences that
   were embedded in the SSN.
