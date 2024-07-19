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

   python create_est_nextflow_params.py family --output-dir results/ --efi-config efi.config --fasta-db uniprot.fasta --efi-db efi_202406 --sequence-version uniprot --families IPR04455

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
      "sequence_version": "uniprot"
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

   python create_nextflow_job.py est family --output-dir results/ --efi-config efi.config --efi-db efi_202406 --fasta-db combined.fasta --sequence-version uniprot --families IPR04455

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

Troubleshooting
---------------

My pipeline crashes because a process was killed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If the process is ``all_by_all_blast``, ``blast_reduce``, or ``compute_stats``, then
this is likely because DuckDB tried to allocate too much memory. You can try
decreasing the number of DuckDB threads with the ``--duckdb-threads`` option on
the template rendering scripts or increasing the soft-limit on memory usage with
``--duckdb-memory-limit``. DuckDB generally does a good job of swapping results to
disk if it is memory constrained but some operations require some minimum amount
of memory. If these solutions did not solve the problem, try using the newest
version of DuckDB (which may require manually building the docker image) or
decreasing the number of ``--blast-matches`` which will reduce the total number of
edges processed. Multiplexing will also reduce the number of sequences analyzed
and can help solve these errors.

Execution Details
-----------------

.. .. image:: images/pipelines/est.png
..    :alt: Visualization of EST pipeline

The EST pipeline consists of different stages which transform the input
sequences into network edges. The stages are executed roughly in this
chronological order

1. **Import Sequences**. EST supports several methods of obtaining sequences.
   The pipeline uses parameters from the various methods to create a list of
   accession IDs. This list is then split into shards and the translation of
   accession IDs to sequences is performed concurrently, resulting in a number
   of FASTA files equal to the number of accession ID file shards.

   If the input mode is a FASTA file, accesison IDs will still try to be
   identified so that taxonomy information can be associated with the sequences.
   The ID headers in the file may be rewritten internally.

   If multiplexing is enabled, CD-HIT will be used to reduce the set of imported
   sequences to a representiative subset. A smaller number of sequences will be
   used in the all-by-all BLAST, meaning it should execute more quickly and
   return a smaller number of edges. The alignment score and other values from
   each representative sequence is then assigned to each of the sequences for
   which it acted as a proxy in the demultiplexing stage (see
   ``src/est/mux/demux.pl``).

2. **Create BLAST Database and split FASTA**. The FASTA files from the previous
   stage are combined into a single file and are then used to created a BLAST
   database. The FASTA file is split again, this time to enable concurrent
   execution of BLAST. The number of shards in this split should be much higher
   than the number of shards used in the import step (because the BLAST
   computations scale better). EFI-EST uses a non-parallelized version of BLAST;
   splitting the input file allows for running multiple searches simultaneously.

3. **All-by-all BLAST**. Every sequence in the FASTA file is used as a query
   against the BLAST database. Shards of the FASTA from the previous step can be
   run in parallel. The result of this process is a multiset of edges between
   sequences. In this stage, the BLAST tabular output is converted to
   `Parquet <https://parquet.apache.org/>`_ files for more efficient processing.
   The conversion is referred to as "transcoding" in the code. The is the most
   computationally intensive stage of the pipeline.

4. **BLASTreduce**. All-by-all BLAST creates a multiset of directed edges, but a
   set without duplicity is needed to generate the network. This stage selects
   the edges that best represent the similarity between two sequences. This
   stage may be computationally intensive if the number of edges is high.

   If mulitplexing was used, demultiplexing occurs after BLASTreduce.

5. **Compute Statistics**. One of the primary outputs of the EST pipeline is a
   set of plots which show the distribution of percent identity and sequence
   length as a function of alignment score. In this stage, five-number summaries
   of percent identity and alignment length at each alignment score are
   calculated, along with a cumulative sum of alignment score counts and a
   convergence ratio metric.

6. **Visualization**. In this stage, the five-number summaries are rendered into
   plots. A histogram of edge lengths is also produced.

7. **Output**. This stage copies all of the pertinent files generated by the
   pipeline to the user-specified output directory. In the future it may
   generate an HTML report or compressed archive.