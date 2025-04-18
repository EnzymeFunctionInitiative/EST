create_gnd
==========
Usage
-----

::

	Usage: perl pipelines/gnd/create_gnd.pl --cluster-map <FILE> --gnd <FILE> --config <FILE>
	    --db-name <VALUE> [--nb-size <VALUE>]
	
	Description:
	    Computes the genome neighborhood network (GNN) from output from the Color SSN pipeline
	
	Options:
	    --cluster-map    path to a file mapping sequence ID to cluster number
	    --gnd            path to the output GND file
	    --nb-size        neighborhood size (number of sequences to retrieve on either side of query
	    --config         path to the config file for database connection
	    --db-name        name of the EFI database to connect to for retrieving UniRef sequences

Reference
---------


NAME
----

``create_gnd.pl`` - read a SSN XGMML file and write it to a new file
after adding new attributes



SYNOPSIS
--------

::

   create_gnd.pl --cluster-map <FILE> --gnd <FILE> --config <FILE> --db-name <NAME>
       [--nb-size <INTEGER>]



DESCRIPTION
-----------

``create_gnd.pl`` reads a list of sequences and corresponding cluster
numbers and creates a GND file in SQLite format.



Arguments
~~~~~~~~~

``--cluster-map``
   Path to the input file that maps UniProt sequence ID to a cluster
   number, which can include a list of singletons (i.e. no cluster
   number columns). See ``parse_cluster_map_file()`` in
   **EFI::SSN::Util::ID** for an explanation of the file format.

``--gnd``
   Path to an output file, which is in SQLite format and contains the
   data necessary to visualize genome neighborhood diagrams (GNDs).

``--nb-size``
   Optional number of neighbors on the left and right of the input IDs
   to include in the analysis, an integer > 0.

``--config``
   Path to the ``efi.config`` file used for database connection options.

``--db-name``
   Name of the database to use (path to file for SQLite).
