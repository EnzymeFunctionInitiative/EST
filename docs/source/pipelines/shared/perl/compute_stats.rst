compute_stats
=============
Usage
-----

::

	Usage: perl pipelines/shared/perl/compute_stats.pl --cluster-map <FILE> --seqid-source-map <FILE>
	    --singletons <FILE> --stats <FILE>
	
	Description:
	    Outputs a file listing the convergence ratio for each cluster in the input cluster map
	
	Options:
	    --cluster-map         path to a file mapping sequence ID to cluster number
	    --seqid-source-map    path to a file mapping repnode or UniRef IDs in the SSN to sequence IDs within the repnode or UniRef ID cluster (optional)
	    --singletons          path to a file containing a list of singletons
	    --stats               path to an output file to save statistics to

Reference
---------


NAME
----

``compute_stats.pl`` - computes simple statistics about the input SSN



SYNOPSIS
--------

::

   compute_stats.pl --cluster-map <FILE> --seqid-source-map <FILE> --singletons <FILE>
       --stats <FILE>



DESCRIPTION
-----------

``compute_stats.pl`` computes the number of SSN clusters, number of SSN
singletons, number of SSN nodes (or metanodes), and the total number of
accession IDs in the SSN (including sequences in the metanodes). Also
output is the SSN sequence source (e.g. UniRef/UniProt).



Arguments
~~~~~~~~~

``--cluster-map``
   Path to a file that maps UniProt sequence ID to a cluster number

``--seqid-source-map``
   Path to a file that maps metanodes (e.g. RepNodes or UniRef IDs) that
   are in the SSN to sequence IDs that are within the metanode.

``--singletons``
   Path to a file listing the singletons in the network (e.g. nodes
   without any edges)

``--stats``
   Path to an output file to put the stats in
