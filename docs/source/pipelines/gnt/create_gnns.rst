create_gnns
===========

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
       [--nb-size <INTEGER> --cooc-threshold <NUMBER>]



DESCRIPTION
-----------

``create_gnns.pl`` reads a list of sequences and corresponding cluster
numbers and creates XGMML files for a cluster GNN and Pfam GNN. It
optionally can create tables and metadata with data about the Pfams of
neighbors in the input IDs and a genome neighborhood diagram (GND) file.



Arguments
~~~~~~~~~

``--cluster-map``
   Path to a file that maps UniProt sequence ID to a cluster number,
   which can include a list of singletons.

``--cluster-gnn``
   Path to the output cluster-centric GNN in XGMML (XML) format.

``--pfam-gnn``
   Path to the output Pfam-centric GNN in XGMML (XML) format.

``--gnd``
   Optional path to an output file in SQLite format that contains the
   data necessary to visualize genome neighborhood diagrams (GNDs).

``--cooc-table``
   Path to a file that will contain co-occurrences for every Pfam of
   every neighbor of every ID in the input ID list.

``--hub-count``
   Path to a file that will contain the size of every cluster hub (e.g.
   how many IDs had neighbors vs how how many IDs in the cluster).

``--nb-pfam-list-dir``
   Path to a directory that will contain tables for every Pfam for all
   of the neighbors of the input IDs. Four sub-directories are created:
   ``pfam``, ``pfam_split``, ``all_pfam``, and ``all_pfam_split``.

``--no-context``
   Path to a file that will contain a list of input IDs without ENA data
   or without neighbors.

``--nb-size``
   Number of neighbors on the left and right of the input IDs to include
   in the analysis. This is an integer > 0.

``--cooc-threshold``
   The co-occurrence threshold to use for computing the Pfam hubs. This
   is a real number >= 0 and <= 1.

``--config``
   Path to the ``efi.config`` file used for database connection options

``--db-name``
   Name of the database to use (path to file for SQLite)
