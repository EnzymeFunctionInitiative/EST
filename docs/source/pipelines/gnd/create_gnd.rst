create_gnd
==========
Usage
-----

::

	Usage: perl pipelines/gnd/create_gnd.pl --cluster-map <FILE> --gnd <FILE> --efi-config <FILE>
	    --efi-db <VALUE> [--nb-size <VALUE>] [--sequence-version <VALUE>] [--title <VALUE>]
	    [--source-type <VALUE>] [--source-sequence-file <VALUE>] [--stats <VALUE>]
	
	Description:
	    Computes the genome neighborhood network (GNN) from output from the Color SSN pipeline
	
	Options:
	    --cluster-map             path to a file mapping sequence ID to cluster number
	    --gnd                     path to the output GND file
	    --nb-size                 neighborhood size (number of sequences) to retrieve on either side of query (> 0 and <= 20)
	    --sequence-version        the input sequence ID type; one of uniprot, uniref90, uniref50, defaults to uniprot if not specified
	    --efi-config              path to the config file for database connection
	    --efi-db                  name of the EFI database to connect to for retrieving UniRef sequences
	    --title                   title of the GND, metadata
	    --source-type             the source of the data provided, e.g. BLAST, FASTA, ID list
	    --source-sequence-file    path to a file containing the sequence used to generate the results, only valid for BLAST sources
	    --stats                   path to file to output GND statistics to
