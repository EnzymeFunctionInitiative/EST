unzip_xgmml_file
================

Reference
---------


NAME
----

``unzip_xgmml_file.pl`` - unzips a compressed XGMML file



SYNOPSIS
--------

::

   unzip_xgmml_file.pl --cluster-map <FILE> --seqid-source-map <FILE> --singletons <FILE>
       --stats <FILE>



DESCRIPTION
-----------

``unzip_xgmml_file.pl`` uncompresses the zip file and extracts the first
XGMML file (``.xgmml`` extension>) that is found. It uses the system
``unzip`` command.



Arguments
~~~~~~~~~

``--in``
   Path to a zip file

``--out``
   Path to the location where the XGMML file should be stored

``--out-ext``
   The file extension in the archive to look for (defaults to
   ``.xgmml``)
