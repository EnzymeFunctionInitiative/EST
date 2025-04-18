filter_ids
==========
Usage
-----

::

	Usage: perl pipelines/est/import/filter_ids.pl --efi-config-file <FILE> --efi-db <VALUE>
	    [--output-dir <DIR_PATH>] [--filter <VALUE>] [--source-meta-file <FILE>]
	    [--source-ids-file <FILE>] [--sequence-version <VALUE>] [--sequence-meta-file <FILE>]
	    [--accession-table-file <FILE>] [--sequence-ids-file <FILE>] [--source-stats-file <FILE>]
	    [--stats-file <FILE>]
	
	Description:
	    Apply filters to the EST pipeline import retrieval
	
	    Filter IDs to remove fragments, restrict to taxonomic categories, etc.
	
	Options:
	    --output-dir              path to directory to store output in; if not specified, defaults to current working directory
	    --efi-config-file         path to EFI database configuration file
	    --efi-db                  EFI database name, or path to EFI SQLite database file
	    --filter                  filters to apply (predef-name, predef-file, user-file, fragments, fraction)
	    --source-meta-file        path to the input file containing the source data to filter
	    --source-ids-file         path to the input file that contains UniRef and UniProt accession IDs
	    --sequence-version        source sequence type (one of uniprot, uniref90, uniref50), defaults to uniprot
	    --sequence-meta-file      path to the output file to save filtered sequences to
	    --accession-table-file    path to the output file to save the filtered UniRef and UniProt accession ID table to (for sunburst)
	    --sequence-ids-file       path to the output file to save filtered sequence IDs to (for sequence retrieval)
	    --source-stats-file       path to the file containing source import stats
	    --stats-file              path to the file to save filter statistics to (appends to source stats)
	
