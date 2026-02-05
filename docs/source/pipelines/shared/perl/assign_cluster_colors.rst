assign_cluster_colors
=====================
Usage
-----

::

	Usage: perl pipelines/shared/perl/assign_cluster_colors.pl --cluster-num-map <FILE>
	    --cluster-color-map <FILE>
	
	Description:
	    Read cluster mapping files and assign colors to each cluster
	
	Options:
	    --cluster-num-map      path to input file containing the mapping of cluster number to cluster sizes
	    --cluster-color-map    path to output file mapping cluster number (sequence count) to a color

Reference
---------


NAME
----

**assign_cluster_colors.pl** - read cluster mapping files and assign
colors to each cluster



SYNOPSIS
--------

::

   assign_cluster_colors.pl --cluster-num-map <FILE> --cluster-color-map <FILE>



DESCRIPTION
-----------

**assign_cluster_colors.pl** reads the cluster mapping file and assigns
a color to each cluster number based on size.



Arguments
~~~~~~~~~

``--cluster-num-map``
   Path to a file that maps cluster number to sizes; the file is four
   columns with the columns being seq-cluster-num, seq-cluster-size,
   node-cluster-num, node-cluster-size

``--cluster-color-map``
   Path to output file that maps cluster number based on sequence count
   to the color as determined by the pipeline upstream
