compute_conv_ratio
==================

Reference
---------


NAME
----

``compute_conv_ratio.pl`` - compute the cluster-based convergence ratio



SYNOPSIS
--------

::

   compute_conv_ratio.pl --cluster-map <FILE> --index-seqid-map <FILE> --edgelist <FILE>
       --conv-ratio <FILE> [--seqid-source-map <FILE>]



DESCRIPTION
-----------

``compute_conv_ratio.pl`` computes the convergence ratio for each
cluster in the input cluster map file and outputs it to a tab-separated
table.



Arguments
~~~~~~~~~

``--cluster-map``
   Path to a file that maps UniProt sequence ID to a cluster number

``--index-seqid-map``
   Path to a file that maps the node index (value in the edgelist) to
   the sequence ID (e.g node label)

``--edgelist``
   Path to a file containing the edgelist of the SSN; each line is
   space-separated pair of node indices

``--conv-ratio``
   Path to an output file to store the convergence ratios in

``--seqid-source-map``
   Optional path to a file that maps metanodes (e.g. RepNodes or UniRef
   IDs) that are in the SSN to sequence IDs that are within the
   metanode. If present the convergence ratio is calculated by taking
   into account the full cluster size.
