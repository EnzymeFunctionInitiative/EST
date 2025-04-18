color_xgmml
===========
Usage
-----

::

	Usage: perl pipelines/shared/perl/color_xgmml.pl --ssn <FILE> --color-ssn <FILE>
	    --cluster-map <FILE> --cluster-num-map <FILE> [--cluster-color-map <FILE>]
	
	Description:
	    Parses a SSN XGMML file and writes it to a new SSN file after coloring and numbering the nodes
	    based on cluster. This is done without creating a DOM since elements are written one by one to
	    the file as they are built.
	
	Options:
	    --ssn                  path to input XGMML (XML) SSN file
	    --color-ssn            path to output colored SSN (XGMML) file
	    --cluster-map          path to output file mapping node index (col 1) to cluster numbers (num by seq, num by nodes)
	    --cluster-num-map      path to input file containing the mapping of cluster number to cluster sizes
	    --cluster-color-map    path to output file mapping cluster number (sequence count) to a color

Reference
---------


NAME
----

``color_xgmml.pl`` - read a SSN XGMML file and write it to a new file
after adding new attributes



SYNOPSIS
--------

::

   color_xgmml.pl --ssn <FILE> --color-ssn <FILE> --cluster-map <FILE> --cluster-num-map <FILE>
       [--cluster-color-map <FILE>] [--color-file <FILE>]



DESCRIPTION
-----------

**color_xgmml.pl** reads a SSN in the format of XGMML (XML) and writes
it to a new file after adding cluster number and color attributes. The
document is read and written in a stream-like fashion rather than
creating and building a DOM for optimal memory usage.



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
   Optional path to an output file that maps cluster number based on
   sequence count to the color as determined by the pipeline upstream

``--color-file``
   Path to a file containing the master color list. If not present then
   the color map in **EFI::Util::Colors** is used.
