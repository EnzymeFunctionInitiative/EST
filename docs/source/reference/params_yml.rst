
Pipeline Parameter Files
========================

A parameter file is provided to each Nextflow run that specifies the values necessary to execute
a pipeline. The file is in YAML format (JSON-compatible). An example for each type of pipeline is
provided below.

Color SSN Pipeline Parameters
-----------------------------

::

    {
        "final_output_dir": "/results/dir",
        "ssn_input": "/path/to/input/ssn.xgmml",
        "fasta_db": "/path/to/blastdb/combined.fasta",
        "efi_config": "/path/to/efi.config",
        "efi_db": "/path/to/efi_db.sqlite"
    }

EST Pipeline Parameters
-----------------------

::

    {
        "final_output_dir": "/results/dir",
        "duckdb_memory_limit": "8GB",
        "duckdb_threads": 1,
        "num_fasta_shards": 128,
        "num_accession_shards": 16,
        "num_blast_matches": 250,
        "job_id": 131,
        "efi_config": "/path/to/efi.config",
        "fasta_db": "/path/to/blastdb/combined.fasta",
        "efi_db": "/path/to/efi_db.sqlite",
        "import_mode": "family",
        "exclude_fragments": false,
        "multiplex": false,
        "blast_evalue": "1e-5",
        "sequence_version": "uniprot",
        "families": "PF07476"
    }

If EST is run using a different option, for example BLAST, then the file contents can vary: ::

    {
        "final_output_dir": "/est_blast/results/dir",
        "duckdb_memory_limit": "8GB",
        "duckdb_threads": 1,
        "num_fasta_shards": 128,
        "num_accession_shards": 16,
        "num_blast_matches": 250,
        "job_id": 131,
        "efi_config": "/path/to/efi.config",
        "fasta_db": "/path/to/blastdb/combined.fasta",
        "efi_db": "/path/to/efi_db.sqlite",
        "import_mode": "blast",
        "exclude_fragments": null,
        "multiplex": false,
        "blast_evalue": "1e-5",
        "sequence_version": "uniprot",
        "blast_query_file": "/path/to/blast_query.fa",
        "import_blast_fasta_db": "/path/to/blastdb/combined.fasta"
    }

EST Generate SSN Pipeline Parameters
------------------------------------

This file is usually created in a subdirectory ``ssn/`` of the main EST results directory.

::

    {
        "blast_parquet": "/est_blast/results/dir/1.out.parquet",
        "fasta_file": "/est_blast/results/dir/all_sequences.fasta",
        "seq_meta_file": "/est_blast/results/dir/sequence_metadata.tab",
        "final_output_dir": "/est_blast/results/dir/ssn",
        "filter_parameter": "alignment_score",
        "filter_min_val": 87.0,
        "min_length": 0,
        "max_length": 50000,
        "ssn_name": "testssn",
        "ssn_title": "test-ssn",
        "maxfull": 0,
        "uniref_version": 1,
        "efi_config": "/path/to/efi.config",
        "db_version": 1,
        "job_id": 131,
        "efi_db": "/path/to/efi_db.sqlite"
    }

GND Pipeline Parameters
-----------------------

::

    {
        "final_output_dir": "/results/dir",
        "cluster_id_map": "/path/to/idlist/file.txt",
        "efi_config": "/path/to/efi.config",
        "efi_db": "/path/to/efi_db.sqlite"
    }

