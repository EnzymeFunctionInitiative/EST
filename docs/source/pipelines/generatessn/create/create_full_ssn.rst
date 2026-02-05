create_full_ssn
===============
Usage
-----

::

	Usage: perl pipelines/generatessn/create/create_full_ssn.pl --blast <FILE> --fasta <FILE>
	    --metadata <FILE> --output <VALUE> [--title <VALUE>] [--max-edges <VALUE>]
	    [--db-version <VALUE>] [--use-min-edge-attr] [--nc-map <VALUE>] [--stats <VALUE>]
	
	Description:
	    Organizes the IDs in the input cluster map file into files by cluster
	
	Options:
	    --blast                path to file containing BLAST all-by-all results
	    --fasta                path to file containing FASTA sequences used in BLAST
	    --metadata             path to file containing sequence metadata
	    --output               path to output file
	    --title                SSN title
	    --max-edges            maximum number of edges to write to file; exits with error if number of edges exceeds this value
	    --db-version           EFI database version
	    --use-min-edge-attr    only use the minimum number of edge attributes required; makes file size smaller
	    --nc-map               path to a network connectivity map file
	    --stats                path to file to output SSN statistics to
