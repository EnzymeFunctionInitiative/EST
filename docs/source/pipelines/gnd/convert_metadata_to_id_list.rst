convert_metadata_to_id_list
===========================
Usage
-----

::

	Usage: perl pipelines/gnd/convert_metadata_to_id_list.pl --cluster-id-mapping <FILE>
	    --source-ids-file <FILE> --source-meta-file <FILE> [--sequence-version <VALUE>]
	
	Description:
	    Converts a sequence ID metadata file output from get_sequence_ids.pl in the shared pipelines
	    into an ID list file that can be used by the GND pipeline.
	
	Options:
	    --cluster-id-mapping    path to the output file mapping sequence ID to cluster number
	    --sequence-version      source sequence type (one of uniprot, uniref90, uniref50), defaults to uniprot
	    --source-ids-file       path to the input file that contains UniRef and UniProt accession IDs
	    --source-meta-file      path to the input file containing the source data to filter
