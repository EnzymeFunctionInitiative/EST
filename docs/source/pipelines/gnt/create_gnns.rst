create_gnns
===========
Usage
-----

::

	Usage: perl pipelines/gnt/create_gnns.pl --cluster-map <FILE> --cluster-gnn <FILE> --pfam-gnn <FILE>
	    --config <FILE> --db-name <VALUE> [--gnd <FILE>] [--cooc-table <FILE>] [--hub-count <FILE>]
	    [--nb-pfam-list-dir <DIR_PATH>] [--no-context <FILE>] [--nb-size <VALUE>]
	    [--cooc-threshold <VALUE>] [--title <VALUE>]
	
	Description:
	    Computes the genome neighborhood network (GNN) from output from the Color SSN pipeline
	
	Options:
	    --cluster-map         path to a file mapping sequence ID to cluster number
	    --cluster-gnn         path to the output cluster hub-spoke GNN XGMML file
	    --pfam-gnn            path to the output Pfam hub-spoke GNN XGMML file
	    --gnd                 path to the output GND file
	    --cooc-table          path to the output Pfam co-occurence table file
	    --hub-count           path to the output hub count table file
	    --nb-pfam-list-dir    path to an output directory containing files for each Pfam hub
	    --no-context          path to an output file to save a list of input IDs that didn't have an ENA entry or didn't have neighbors
	    --nb-size             neighborhood size (number of sequences) to retrieve on either side of query (> 0 and <= 20)
	    --cooc-threshold      cooccurrence threshold (>= 0.0 and <= 1.0)
	    --config              path to the config file for database connection
	    --db-name             name of the EFI database to connect to for retrieving UniRef sequences
	    --title               title of the GNN and GND for display purposes

Reference
---------


NAME
----

``create_gnns.pl`` - read a SSN XGMML file and write it to a new file
after adding new attributes



SYNOPSIS
--------

::

   create_gnns.pl --cluster-map <FILE> --cluster-gnn <FILE> --pfam-gnn <FILE>
       --config <FILE> --db-name <NAME> [--gnd <FILE> --cooc-table <FILE>]
       [--hub-count <FILE> --nb-pfam-list-dir <DIR> --no-context FILE
       [--nb-size <INTEGER> --cooc-threshold <NUMBER> --title "<TITLE>"]



DESCRIPTION
-----------

``create_gnns.pl`` reads a list of sequences and corresponding cluster
numbers and creates XGMML files for a cluster GNN and Pfam GNN. It
optionally can create tables and metadata with data about the Pfams of
neighbors in the input IDs and a genome neighborhood diagram (GND) file.



Arguments
~~~~~~~~~

``--cluster-map``
   Path to the input file that maps UniProt sequence ID to a cluster
   number, which can include a list of singletons (i.e. no cluster
   number columns). See ``parse_cluster_map_file()`` in
   **EFI::SSN::Util::ID** for an explanation of the file format.

``--cluster-gnn``
   Path to the output cluster-centric GNN in XGMML (XML) format. This
   file can be viewed in Cytoscape.

``--pfam-gnn``
   Path to the output Pfam-centric GNN in XGMML (XML) format. This file
   can be viewed in Cytoscape.

``--gnd``
   Optional path to an output file in SQLite format containing the data
   necessary to visualize genome neighborhood diagrams (GNDs).

``--cooc-table``
   Optional path to an output file containing co-occurrences for every
   Pfam of every neighbor of every ID in the input ID list. The file is
   a tab-separated file with the first column being a list of Pfams and
   each successive column being a cluster number and the co-occurrence
   of the Pfam in that cluster.

``--hub-count``
   Optional path to an output tab-separated file containing the size of
   every cluster hub, with the first column being the cluster number,
   the second column (NumQueryableSeq) containing the number of
   sequences in the cluster that had neighbors, and the third column
   (TotalNumSeq) containing the total number of sequences in the
   cluster.

``--nb-pfam-list-dir``
   Optional path to an output directory containing tables for every Pfam
   group for all of the neighbors of the input IDs. Four sub-directories
   are created: ``pfam`` (Pfam groups filtered by co-occurrence),
   ``pfam_split`` (Pfam groups split into constituent families, filtered
   by co-occurrence), ``all_pfam`` (all Pfam groups, not filtered by
   co-occurrence), and ``all_pfam_split`` (Pfam groups split into
   constituent families, not filtered by co-occurrence).

``--no-context``
   Optional path to an output file that contains a list of input IDs
   without ENA data or without neighbors.

``--nb-size``
   Optional number of neighbors on the left and right of the input IDs
   to include in the analysis, an integer > 0 and <= 20.

``--cooc-threshold``
   Optional co-occurrence threshold to use for computing the Pfam hubs,
   a real number >= 0 and <= 1.

``--config``
   Path to the ``efi.config`` file used for database connection options.

``--db-name``
   Name of the database to use (path to file for SQLite).

``--title``
   Optional title to use for display purposes in the GND viewer.
