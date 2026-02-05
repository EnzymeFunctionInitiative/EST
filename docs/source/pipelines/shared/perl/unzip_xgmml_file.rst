unzip_xgmml_file
================
Usage
-----

::

	Usage: perl pipelines/shared/perl/unzip_xgmml_file.pl --in <FILE> --out <FILE> [--out-ext <FILE>]
	
	Description:
	    Extracts the first .xgmml (or specified extension) file in the input archive.
	
	Options:
	    --in         path to zip file
	    --out        path to output first xgmml file to
	    --out-ext    file extension to look for (defaults to xgmml)

Reference
---------


NAME
----

unzip_xgmml_file.pl - unzips a compressed XGMML file



SYNOPSIS
--------

::

   unzip_xgmml_file.pl --in <FILE> --out <FILE> [--out-ext <FILE_EXT>]



DESCRIPTION
-----------

**unzip_xgmml_file.pl** uncompresses the zip file and extracts the first
file matching the specified file extension by ``--out-ext``. If
``--out-ext`` is not specified then the first XGMML file (with
``.xgmml`` extension) is extracted. This script requires that the system
have the **unzip** program installed.



Arguments
~~~~~~~~~

``--in``
   Path to a zip file.

``--out``
   Path to the file where the XGMML file should be extracted to. If a
   file at that path already exists it will be deleted.

``--out-ext``
   The file extension in the archive to look for (defaults to
   ``.xgmml``).
