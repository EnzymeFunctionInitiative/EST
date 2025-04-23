.. EST documentation master file

Enzyme Similarity Tool
======================

The Enzyme Similarity Tool (EST) pipeline computes the similarity between
proteins.  Various input modes are available to allow computations based on
BLAST similarity and sequences from families, FASTA files, and accession ID
lists.

Running the Pipeline
--------------------

Generating a Parameter File
~~~~~~~~~~~~~~~~~~~~~~~~~~~

The EST pipeline runs in four different modes, and a parameter file necessary
to run the pipeline is created with ``bin/create_est_nextflow_params.py``: ::

    python bin/create_est_nextflow_params.py family --families PF07476 --fasta-db uniprot.fasta --sequence-version uniprot --output-dir results/ --efi-config efi.config --efi-db efi_202406 --nextflow-config file.config

A file ``params.yml`` that contains the information needed to run the EST
pipeline is created in ``results/``.  Additionally, a shell script
``run_nextflow.sh`` is output to the same directory.  See
:doc:`../../reference/params_yml` for more information on the file format.  The
pipeline may then be executed using the shell script: ::

    bash results/run_nextflow.sh

The first argument to ``create_est_nextflow_params.py`` is positional and
specifies the mode, one of the following:

* **blast**: perform a BLAST using an input sequence to determine similarity

* **family**: determine similarity between members of a protein family

* **fasta**: determine similarity between sequences within a FASTA file

* **accessions**: determine similarity between sequences given by the UniProt
  IDs in a file

EST pipeline-specific arguments for the various modes are:

* **blast** mode:

  * ``--blast-query-file``: path to a file containing a single sequence.
    [*required*]

  * ``--import-blast-fasta-db``: optional path to an alternative sequence
    database, used when the ``--sequence-version`` option is provided.

  * ``--import-blast-num-matches``: optional integer value used to set the
    maximum number of sequence alignment matches returned from the initial
    ``blastall`` call used to retrieve sequences to be further analyzed. 
    Default value is 1000. 
  
  * ``--import-blast-evalue``: optional float value setting the threshold
    e-value applied to the initial ``blastall`` call used to retrieve sequences
    to be further analyzed. Default value is 1e-5. 
    

* **families** mode:

  * ``--families``: list of families to obtain sequences from.  This option can
    be used by any input mode to add families to the selected inputs.
    [*required*]

* **fasta** mode:
  
  * ``--fasta``: path to FASTA file containing many sequences.  The FASTA
    headers are scanned for UniProt sequence identifiers, and if any are found
    then the sequence from the UniProt database is used (not the one in the
    input file).  If no UniProt sequence was found then the sequences in the
    file are used and given an name starting with ``ZZ``. [*required*]

* **accessions** mode:

    * ``--accessions-file``: path to a file containing UniProt or
      UniProt-compatible IDs. [*required*]

* common arguments shared between the EST modes:

  * ``--fasta-db``: path to a BLAST-formatted database where sequences are
    retrieved from. [*required for all modes*]

  * ``--sequence-version``: if present, specifies which sequence database to
    retrieve sequences from; available values are ``uniprot`` (default),
    ``uniref90``, and ``uniref50``.  If UniRef is used:

    * For mode **family**, then only UniRef sequences that are in the specified
      families are retrieved and used.  This reduces the number of sequences
      that are used in the computation, therefore reducing computation time and
      size of the outputs.

    * For mode **blast**, the input sequence is BLAST'ed against the UniRef
      sequence database to only find UniRef sequences that are similar.

    * If the ``--families`` argument is present for modes **blast**, **fasta**,
      or **accessions**, then only UniRef sequences are retrieved for the
      specified families.

  * ``--exclude-fragments``: include only complete sequences in the computation;
    i.e. exclude the UniProt database.

See :doc:`../../reference/common_args` for information on the other, required
arguments.

Generating a Job Script
~~~~~~~~~~~~~~~~~~~~~~~

The pipelines were designed to run on a cluster because of the large dataset
and computational intensity.  An additional script is provided which can
generate a job script for SLURM as well as the parameter file.  To generate
these files, ::

    python bin/create_nextflow_job.py est family --families PF07476 --fasta-db combined.fasta --sequence-version uniprot --output-dir results/ --efi-config efi.config --efi-db efi_202406 --nextflow-config slurm.config

In addition to the ``params.yml`` seen above, this will generate a SLURM job
submission script called ``run_nextflow.sh`` which can be started by running
``sbatch run_nextflow.sh``.

Troubleshooting
---------------

My pipeline crashes because a process was killed
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If the process is ``all_by_all_blast``, ``blast_reduce``, or ``compute_stats``,
then this is likely because DuckDB tried to allocate too much memory.  You can
try decreasing the number of DuckDB threads with the ``--duckdb-threads``
option on the template rendering scripts or increasing the soft-limit on memory
usage with ``--duckdb-memory-limit``.  DuckDB generally does a good job of
swapping results to disk if it is memory constrained but some operations
require some minimum amount of memory.  If these solutions did not solve the
problem, try using the newest version of DuckDB (which may require manually
building the docker image) or decreasing the number of ``--blast-num-matches``
which will reduce the total number of edges processed.  Multiplexing will also
reduce the number of sequences analyzed and can help solve these errors.

Execution Details
-----------------

.. .. image:: images/pipelines/est.png
..    :alt: Visualization of EST pipeline

The EST pipeline consists of different stages which transform the input
sequences into network edges.  The stages are executed roughly in this
chronological order:

1. **Import Sequences**.  EST supports several methods of obtaining sequences.
   The pipeline uses parameters from the various methods to create a list of
   accession IDs.  This list is then split into shards and the translation of
   accession IDs to sequences is performed concurrently, resulting in a number
   of FASTA files equal to the number of accession ID file shards.

   If the input mode is a FASTA file, accession IDs will still try to be
   identified so that taxonomy information can be associated with the sequences.
   The ID headers in the file may be rewritten internally.

   If multiplexing is enabled, CD-HIT will be used to reduce the set of imported
   sequences to a representative subset.  A smaller number of sequences will be
   used in the all-by-all BLAST, meaning it should execute more quickly and
   return a smaller number of edges.  The alignment score and other values from
   each representative sequence is then assigned to each of the sequences for
   which it acted as a proxy in the demultiplexing stage (see
   ``src/est/mux/demux.pl``).

2. **Create BLAST Database and split FASTA**.  The FASTA files from the previous
   stage are combined into a single file and are then used to created a BLAST
   database.  The FASTA file is split again, this time to enable concurrent
   execution of BLAST.  The number of shards in this split should be much higher
   than the number of shards used in the import step (because the BLAST
   computations scale better).  EFI-EST uses a non-parallelized version of BLAST;
   splitting the input file allows for running multiple searches simultaneously.

3. **All-by-all BLAST**.  Every sequence in the FASTA file is used as a query
   against the BLAST database.  Shards of the FASTA from the previous step can be
   run in parallel.  The result of this process is a multiset of edges between
   sequences.  In this stage, the BLAST tabular output is converted to
   `Parquet <https://parquet.apache.org/>`_ files for more efficient processing.
   The conversion is referred to as "transcoding" in the code.  This is the most
   computationally intensive stage of the pipeline.

4. **BLASTreduce**.  All-by-all BLAST creates a multiset of directed edges, but a
   set without duplicity is needed to generate the network.  This stage selects
   the edges that best represent the similarity between two sequences.  This
   stage may be computationally intensive if the number of edges is high.

   If mulitplexing was used, demultiplexing occurs after BLASTreduce.

5. **Compute Statistics**.  One of the primary outputs of the EST pipeline is a
   set of plots which show the distribution of percent identity and sequence
   length as a function of alignment score.  In this stage, five-number summaries
   of percent identity and alignment length at each alignment score are
   calculated, along with a cumulative sum of alignment score counts and a
   convergence ratio metric.

6. **Visualization**.  In this stage, the five-number summaries are rendered into
   plots.  A histogram of edge lengths is also produced.

7. **Output**.  This stage copies all of the pertinent files generated by the
   pipeline to the user-specified output directory.  In the future it may
   generate an HTML report or compressed archive.

Stages
~~~~~~

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

