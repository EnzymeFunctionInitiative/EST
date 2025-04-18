color_gnt_xgmml
===============
Usage
-----

::

	Usage: perl pipelines/gnt/color_gnt_xgmml.pl --ssn <FILE> --color-gnt-ssn <FILE>
	    --cluster-map <FILE> --cluster-num-map <FILE> --cluster-color-map <FILE> --metanode-map <FILE>
	    --gnd <FILE>
	
	Description:
	    Parses a SSN XGMML file and writes it to a new SSN file after coloring and numbering the nodes
	    based on cluster, and adding GNT node attributes.
	
	Options:
	    --ssn                  path to input XGMML (XML) SSN file
	    --color-gnt-ssn        path to output SSN (XGMML) file containing color and GNT metadata
	    --cluster-map          path to input file mapping node index (col 1) to cluster numbers (num by seq, num by nodes)
	    --cluster-num-map      path to input file containing the mapping of cluster number to cluster sizes
	    --cluster-color-map    path to input file mapping cluster number (sequence count) to a color
	    --metanode-map         path to input file mapping metanode (e.g. UniRef node) to members of metanode
	    --gnd                  path to input SQLite file with GNDs; used to obtain GNT data

Reference
---------


NAME
----

**color_gnt_xgmml.pl** - read a SSN XGMML file and write it to a new
file after adding color and GNT attributes



SYNOPSIS
--------

::

   color_gnt_xgmml.pl --ssn <FILE> --color-ssn <FILE> --cluster-map <FILE> --cluster-num-map <FILE>
       --cluster-color-map <FILE> --metanode-map <FILE> --gnd <FILE>



DESCRIPTION
-----------

**color_gnt_xgmml.pl** reads a SSN in the XGMML (XML) format and writes
it to a new file after adding cluster number, color, and genome
neighborhood tool (GNT) attributes such as ENA status and neighboring
families.



Arguments
~~~~~~~~~

``--ssn``
   Path to the input SSN

``--color-ssn``
   Path to the output SSN

``--cluster-map``
   Path to a file that maps UniProt sequence ID to a cluster number

``--cluster-num-map``
   Path to a file that maps cluster number to sizes; the file is four
   columns with the columns being seq-cluster-num, seq-cluster-size,
   node-cluster-num, node-cluster-size

``--cluster-color-map``
   Path to a file that maps cluster number based on sequence count to
   the color as determined by the pipeline upstream

``--metanode-map``
   Path to a file that maps metanodes (e.g. UniRef or RepNode nodes in
   the SSN) to UniProt IDs in the metanode. The file will be empty if
   the input SSN is a UniProt network

``--gnd``
   Path to a GND file (SQLite format) that contains genome context data;
   used to obtain neighbor families and ENA status and ID; output from a
   previous step
