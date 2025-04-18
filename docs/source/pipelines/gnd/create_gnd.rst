create_gnd
==========
Usage
-----

::

	Usage: perl pipelines/gnd/create_gnd.pl --cluster-map <FILE> --gnd <FILE> --config <FILE>
	    --db-name <VALUE> [--nb-size <VALUE>] [--title <VALUE>] [--source-type <VALUE>]
	    [--source-sequence-file <VALUE>]
	
	Description:
	    Computes the genome neighborhood network (GNN) from output from the Color SSN pipeline
	
	Options:
	    --cluster-map             path to a file mapping sequence ID to cluster number
	    --gnd                     path to the output GND file
	    --nb-size                 neighborhood size (number of sequences) to retrieve on either side of query (> 0 and <= 20)
	    --config                  path to the config file for database connection
	    --db-name                 name of the EFI database to connect to for retrieving UniRef sequences
	    --title                   title of the GND, metadata
	    --source-type             the source of the data provided, e.g. BLAST, FASTA, ID list
	    --source-sequence-file    path to a file containing the sequence used to generate the results, only valid for BLAST sources
