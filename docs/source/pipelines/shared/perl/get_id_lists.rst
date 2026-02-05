get_id_lists
============
Usage
-----

::

	Usage: perl pipelines/shared/perl/get_id_lists.pl --cluster-map <FILE> --uniprot <DIR_PATH>
	    --cluster-sizes <FILE> --config <FILE> --db-name <VALUE> [--uniref90 <DIR_PATH>]
	    [--uniref50 <DIR_PATH>] [--seqid-source-map <FILE>] [--singletons <FILE>]
	
	Description:
	    Organizes the IDs in the input cluster map file into files by cluster
	
	Options:
	    --cluster-map         path to a file mapping sequence ID to cluster number
	    --uniprot             path to an output directory for storing IDs in
	    --uniref90            path to an output directory for storing UniRef90 IDs in (optional)
	    --uniref50            path to an output directory for storing UniRef50 IDs in (optional)
	    --seqid-source-map    path to a file mapping repnode or UniRef IDs in the SSN to sequence IDs within the repnode or UniRef ID cluster (optional)
	    --singletons          path to a file listing the singletons
	    --cluster-sizes       path to an output file to save cluster sizes to
	    --config              path to the config file for database connection
	    --db-name             name of the EFI database to connect to for retrieving UniRef sequences

Reference
---------


NAME
----

``get_id_lists.pl`` - gets ID lists from the input SSN and stores them
in files by cluster



SYNOPSIS
--------

::

   get_id_lists.pl --cluster-map <FILE> --uniprot <DIR> --cluster-sizes <FILE>
       --config <FILE> --db-name <NAME>
       [--uniref90 <DIR> --uniref50 <DIR> --seqid-source-map <FILE> --singletons <FILE>]



DESCRIPTION
-----------

``get_id_lists.pl`` gets all of the IDs in the SSN and writes them to
files organized by sequence type and cluster number. Each directory
contains the following files:

::

   cluster_<SOURCE>_All.txt
   cluster_<SOURCE>_Cluster_1.txt
   cluster_<SOURCE>_Cluster_2.txt
   ...
   singletons.txt

Where ``<SOURCE``> is ``UniProt``, ``UniRef90``, or ``UniRef50``.

If a RepNode network is the input to the pipeline the nodes are expanded
into the full set of sequences before writing the cluster files.

For UniRef networks, the script assumes that the input to the script via
``--cluster-map`` are UniRef sequences and those are validated first.
Then the sequences are reverse-mapped to UniProt to obtain the UniProt
sequences that correspond to the UniRef equivalent sequence.



Arguments
~~~~~~~~~

``--cluster-map``
   Path to a file that maps UniProt sequence ID to a cluster number

``--uniprot``
   Path to an existing directory that will contain the ID lists for
   UniProt sequences

``--uniref90``
   Optional path to an existing directory for UniRef90 IDs

``--uniref50``
   Optional path to an existing directory for UniRef50 IDs

``--cluster-sizes``
   Path to an output file containing the mapping of clusters to sizes.
   If the input is a UniProt network, then there will be two columns,
   cluster number and UniProt size. If the input is a UniRef90 network,
   then there will be a third column for UniRef90 cluster size. If the
   input is a UniRef50 network, then there will be a fourth column for
   UniRef50 cluster size.

``--config``
   Path to the ``efi.config`` file used for database connection options

``--db-name``
   Name of the database to use (path to file for SQLite)

``--seqid-source-map``
   Optional path to a file that maps metanodes (e.g. RepNodes) that are
   in the SSN to sequence IDs that are within the metanode. Used when
   the input network is a RepNode SSN.

``--singletons``
   Path to a file listing the singletons in the network (e.g. nodes
   without any edges)
