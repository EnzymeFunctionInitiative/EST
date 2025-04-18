get_sunburst_data
=================
Usage
-----

::

	Usage: perl pipelines/est/import/get_sunburst_data.pl --efi-config-file <FILE> --efi-db <VALUE>
	    [--output-dir <DIR_PATH>] [--sequence-meta-file <FILE>] [--accession-table-file <FILE>]
	    [--sunburst-data-file <FILE>] [--pretty-print]
	
	Description:
	    Retrieve taxonomic information and save in a JSON format for Sunburst diagrams
	
	Options:
	    --output-dir              path to directory to store output in; if not specified, defaults to current working directory
	    --efi-config-file         path to EFI database configuration file
	    --efi-db                  EFI database name, or path to EFI SQLite database file
	    --sequence-meta-file      path to the input file that contains sequence metadata
	    --accession-table-file    path to the input file that contains UniRef and UniProt accession IDs
	    --sunburst-data-file      output file to put sunburst data into (defaults into --output-dir)
	    --pretty-print            pretty-print JSON
	

Reference
---------


NAME
----

**get_sunburst_data.pl** - obtain taxonomic data for the input sequences
for sunburst diagrams



SYNOPSIS
--------

::

   get_sunburst_data.pl --efi-config <EFI_CONFIG_FILE> --efi-db <EFI_DB_FILE>
       [--sequence-meta-file <FILE> --accession-table-file <FILE> --sunburst-data-file <FILE>
       --pretty-print]



DESCRIPTION
-----------

This script takes output from the ``filter_ids.pl`` process in the EST
pipeline and retrieves taxonomic information for every sequence in the
input. See **EFI::Sunburst::Data** for a description of the output data.



Arguments
~~~~~~~~~

``--efi-config`` (required)
   The path to the config file used for the database.

``--efi-db`` (required)
   The path to the SQLite database file or the name of a MySQL/MariaDB
   database. The database connection parameters are specified in the
   ``--efi-config`` file.

``--sequence-meta-file`` (required, default value)
   Path to the file containing sequence metadata, such as sequence
   source. Defaults to ``sequence_metadata.tab`` in the current
   directory.

``--accession-table-file`` (required, default value)
   Path to the file containing the accession ID mapping table. Defaults
   to ``accession_table.tab`` in the current directory.

``--sunburst-data-file`` (required, default value)
   Path to the output file that will contain the JSON data necessary for
   the web UI to display sunburst diagrams. Defaults to
   ``sunburst_tax.json`` in the current directory.

``--pretty-print`` (optional)
   Indicates if the JSON output should be human-readable. Defaults to
   false (compact file format).
