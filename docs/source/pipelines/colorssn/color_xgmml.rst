color_xgmml
===========
Usage
-----

::

	Usage: perl pipelines/colorssn/color_xgmml.pl --ssn <FILE> --color-ssn <FILE> --cluster-map <FILE>
	    --cluster-num-map <FILE> --cluster-color-map <FILE>
	
	Description:
	    Parses a SSN XGMML file and writes it to a new SSN file after coloring and numbering the nodes
	    based on cluster.
	
	Options:
	    --ssn                  path to input XGMML (XML) SSN file
	    --color-ssn            path to output SSN (XGMML) file containing color metadata
	    --cluster-map          path to input file mapping node index (col 1) to cluster numbers (num by seq, num by nodes)
	    --cluster-num-map      path to input file containing the mapping of cluster number to cluster sizes
	    --cluster-color-map    path to input file mapping cluster number (sequence count) to a color

Reference
---------


NAME
----

**color_xgmml.pl** - read a SSN XGMML file and write it to a new file
after adding color attributes



SYNOPSIS
--------

::

   color_xgmml.pl --ssn <FILE> --color-ssn <FILE> --cluster-map <FILE> --cluster-num-map <FILE>
       --cluster-color-map <FILE>



DESCRIPTION
-----------

**color_xgmml.pl** reads a SSN in the XGMML (XML) format and writes it
to a new file after adding cluster number and color attributes.



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
