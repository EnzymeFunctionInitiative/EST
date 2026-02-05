ssn_to_id_list
==============

Reference
---------


NAME
----

``ssn_to_id_list.pl`` - gets network information from a SSN



SYNOPSIS
--------

::

   ssn_to_id_list.pl --ssn <FILE> --edgelist <FILE> --index-seqid <FILE>
       --id-index <FILE> --seqid-source-map <FILE>



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
   Path to the input SSN uploaded by the user

``--edgelist``
   Path to the output edgelist, consisting of space separated pairs of
   node indices

``--index-seqid``
   Path to an output file that contains a mapping of node index to
   sequence ID

``--id-index``
   Path to an output file that maps node ID (the ``id`` attribute in a
   node) to node index

``--seqid-source-map``
   Path to an output file that maps metanodes (e.g. RepNodes or UniRef
   nodes) that are in the SSN to sequence IDs that are within the
   metanode.
