color_ssn
=========
Usage
-----

::

	Usage: perl pipelines/neighborhoodconnectivity/color/color_ssn.pl --input <FILE> --output <FILE>
	    --color-map <FILE> --stats <VALUE> [--color-name <VALUE>] [--primary-color]
	
	Description:
	    Colors a SSN XGMML file based on neighborhood connectivity
	
	Options:
	    --input            path to input XGMML (XML) SSN file
	    --output           path to output SSN (XGMML) file containing color metadata
	    --color-map        tab-separated file mapping id to color and connectivity data
	    --color-name       name of the node attribute to store the color into; if the --primary-color flag is present, then also put the color into node.fillColor
	    --primary-color    store the color value into the node.fillColor attribute
	    --stats            path to file to output SSN statistics to

Reference
---------


NAME
----

**color_ssn.pl** - read a SSN XGMML file and write it to a new file
after adding neighborhood connectivity color attributes



SYNOPSIS
--------

::

   color_ssn.pl --input <FILE> --output <FILE> --color-map <FILE> --stats <FILE>
       [--primary-color]



DESCRIPTION
-----------

**color_ssn.pl** reads a SSN in the XGMML (XML) format and writes it to
a new file after adding neighborhood connectivity colors and values. The
columns added are ``Neighborhood Connectivity`` and
``Neighborhood Connectivity Value``, and if the ``--primary-color`` flag
is provided, the ``node.fillColor`` column will be overwritten or added.



Arguments
~~~~~~~~~

``--input``
   Path to the input SSN

``--output``
   Path to the output SSN

``--color-map``
   Path to a file that maps sequence ID to neighborhood connectivity
   value and color. Each line contains sequence ID, color, and
   connectivity value separated by tabs.

``--primary-color``
   Store the color value into the ``node.fillColor`` attribute in
   addition to the ``Neighborhood Connectivity Color`` SSN column.

``--stats``
   Path to a file to write statistics (e.g. number of nodes, edges) to.
