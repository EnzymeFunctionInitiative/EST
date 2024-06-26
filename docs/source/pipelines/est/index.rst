.. EST documentation master file

Enzyme Similarity Tool
===================================================

The EST pipeline consists of the following stages:

.. toctree::
   :maxdepth: 1

   import/index.rst
   mux/index.rst
   split_fasta/index.rst
   axa_blast/index.rst
   blastreduce/index.rst
   demux/index.rst
   statistics/index/.rst
   visualization/index.rst

Running the Pipeline
--------------------

Generating a Parameter File
~~~~~~~~~~~~~~~~~~~~~~~~~~~

The EST pipeline is configured through a file containing parameters. The file
must be valid YAML (JSON is a subset of YAML and will work). The parameters
needed depend on the import mode, so the repo includes a script which ensures
that all of the required options are included. For example, to generate a
parameter file which specifies the Family import mode, the command would look
like ::

   python create_est_nextflow_params.py family --output-dir results/ --efi-config efi.config --fasta-db uniprot.fasta --efi-db efi_202406 --families IPR04455 --family-id-format UniProt

This produces a file ``params.yml`` which looks like ::

   {
      "final_output_dir": "results/",
      "duckdb_memory_limit": "8GB",
      "duckdb_threads": 1,
      "num_fasta_shards": 128,
      "num_accession_shards": 16,
      "num_blast_matches": 250,
      "multiplex": false,
      "job_id": 131,
      "efi_config": "efi.config",
      "fasta_db": "uniprot.fasta",
      "efi_db": "efi_202406",
      "import_mode": "family",
      "exclude_fragments": false,
      "families": "IPR04455",
      "family_id_format": "UniProt"
   }

All parameters may be set by commandline options. Once this file has been
generated, it can be used to control how the pipeline runs: ::

   nextflow run est.nf -params-file params.yml

Generating a Job Script
~~~~~~~~~~~~~~~~~~~~~~~
The EST pipeline was designed to run on a cluster because of the large dataset
and computational intensity. The EST repo contains another script which can
generate a job script for SLURM as well as the parameter file. To generate these
files, ::

   python create_nextflow_job.py est family --output-dir results/ --efi-config efi.config --efi-db efi_202406 --fasta-db combined.fasta --families IPR04455 --family-id-format UniProt

In addition to the ``params.json`` seen above, this will generate a SLURM job
submission script called ``run_nextflow.sh``: ::
   
   #!/bin/bash
   #SBATCH --partition=efi
   #SBATCH -c 2
   #SBATCH --mem=32GB
   #SBATCH --job-name="est-131"
   #SBATCH -o results/nextflow.stdout
   #SBATCH -e results/nextflow.stderr


   module load efidb/ip100
   module load efiest/devlocal
   module load Perl
   module load Python
   module load efiest/python_est_1.0
   module load DuckDB
   source /home/groups/efi/apps/perl_env.sh


   module load nextflow
   nextflow -C conf/slurm.conf run est.nf -ansi-log false -offline -params-file params.yml -with-report report.html -with-timeline timeline.html

The job may be started by running ``sbatch run_nextflow.sh``.