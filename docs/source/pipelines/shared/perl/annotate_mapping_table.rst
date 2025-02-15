annotate_mapping_table
======================
Usage
-----

::

	Usage: perl annotate_mapping_table.pl --cluster-map <FILE> --mapping-table <FILE> --config <FILE>
	    --db-name <VALUE> [--seqid-source-map <FILE>] [--cluster-color-map <FILE>]
	    [--swissprot-table <FILE>]
	
	Description:
	    Outputs a mapping table with UniProt ID, cluster number, cluster color, taxonomy ID, and
	    species corresponding to the UniProt ID
	
	Options:
	    --cluster-map          path to a file mapping sequence ID to cluster number
	    --seqid-source-map     path to a file mapping repnode or UniRef IDs in the SSN to sequence IDs within the repnode or UniRef ID cluster (optional)
	    --mapping-table        path to an output file to store mapping in
	    --cluster-color-map    path to a file mapping cluster number (sequence count) to color (optional)
	    --swissprot-table      path to an output file to store SwissProt mappings in (optional)
	    --config               path to the config file for database connection
	    --db-name              name of the EFI database to connect to for retrieving annotations

Reference
---------


NAME
----

``annotate_mapping_table.pl`` - create a table that has UniProt IDs with
associated attributes



SYNOPSIS
--------

::

   annotate_mapping_table.pl --cluster-map <FILE> --seqid-source-map <FILE> --mapping-table <FILE>
       --config <FILE> --db-name <NAME> [--cluster-color-map <FILE> --swissprot-table <FILE>]



DESCRIPTION
-----------

``annotate_mapping_table.pl`` creates a table of UniProt IDs with
cluster number, cluster color, taxonomy ID, and species as additional
columns.



Arguments
~~~~~~~~~

``--cluster-map``
   Path to a file that maps UniProt sequence ID to a cluster number

``--seqid-source-map``
   Path to a file that maps metanode ID to list of sequence IDs (the
   output table is expanded to include all of these IDs, not just the
   metanodes)

``--mapping-table``
   Path to the output file to store the table in

``--cluster-color-map``
   Optional path to a file that maps cluster number based on sequence
   count to the color as determined by the pipeline upstream

``--swissprot-table``
   Optional path to an output file to store UniProt and associated
   SwissProt data

``--config``
   Path to the ``efi.config`` file used for database connection options

``--db-name``
   Name of the database to use (path to file for SQLite)
