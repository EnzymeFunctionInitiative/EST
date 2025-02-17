Sequence Similarity Network Generation
======================================

This pipeline transforms the edges outputted by the EST pipeline into a
Sequence Similarity Network (SSN).

Running the Pipeline
--------------------

Generating a Parameter File
~~~~~~~~~~~~~~~~~~~~~~~~~~~

The SSN pipeline takes as input a results directory outputted by the EST
pipeline in an "automatic" mode, or the specific necessary files in "manual"
mode.  The parameter file necessary to run the pipeline is created with the
``bin/create_generatessn_nextflow_params.py`` script: ::

    python bin/create_generatessn_nextflow_params.py auto --filter-min-val 23 --ssn-name ssn.xgmml --ssn-title "SSN Title" --est-output-dir est_results/ --efi-config efi.config --efi-db efi_202406 --nextflow-config file.config

A file ``params.yml`` is created in ``est_results/ssn/`` that contains the
information needed to run the EST pipeline.  Additionally, a shell script
``run_nextflow.sh`` is output to the directory.  See
:doc:`../../reference/params_yml` for more information on the file format.  The
pipeline may then be executed using the shell script: ::

    bash results/run_nextflow.sh

The first argument to ``create_generatessn_nextflow_params.py`` is positional
and specifies the mode used to create the SSN.  The value is either ``auto`` or
``manual``.  It is expected that in most cases the ``auto`` mode will be used.
SSN pipeline-specific arguments are:

* **auto** mode:

  * ``--est-output-dir``: path to the directory containing the output from the
    EST pipeline; files in this directory will be used to generate the SSN,
    and the relevant files will automatically be selected. [*required*]

* **manual** mode:

  * ``--blast-parquet``: path to the file containing the BLAST computation
    results from a EST pipeline execution (e.g. the ``1.out.parquet`` file).
    [*required*]

  * ``--fasta-file``: path to the FASTA file that contains the original
    sequences used in the similarity computations. [*required*]

  * ``--seq-meta-file``: path to a file containing metadata for the original
    sequences used in the similarity computations (e.g. sequence source).
    [*required*]

  * ``--uniref-version``: the sequence version to use for the purpose of
    annotations in the SSN; if specified, acceptable values are ``90`` and
    ``50``.

  * ``--db-version``: specifies the version of the EFI database used to
    generate the network.

* common arguments shared between the **auto** and **manual** modes:

  * ``--filter-min-val``: the alignment score to use to segregate sequences
    into clusters; functionally equivalent to retaining rows in the input BLAST
    parquet results where computed alignment score >= this value. [*required*]

  * ``--ssn-name``: the file name to use to save the SSN (e.g. ``ssn.xgmml``).
    The file is saved into the output directory (either ``est_output_dir/ssn``
    in **auto** mode or ``output_dir/`` in **manual** mode). [*required*]

  * ``--ssn-title``: descriptive name of the SSN (e.g. "SSN Test"). [*required*]

  * ``--filter-parameter``: specify which parameter to filter edges on;
    acceptable values are ``pident``, ``alignment_length``, ``bitscore``,
    ``query_length``, and ``alignment_score``.  The default option
    ``alignment_score`` should always be used unless the user is an expert user.

  * ``--min-length``: minimum sequence length to include in the output SSN; all
    sequences less than this value are not included in the SSN.

  * ``--max-length``: maximum sequence length to include in the output SSN; all
    sequences greater than this value are not included in the SSN.  The default
    value is ``50000``.

See :doc:`../../reference/common_args` for information on the other, required
arguments.

Generating a Job Script
~~~~~~~~~~~~~~~~~~~~~~~

The pipelines were designed to run on a cluster because of the large dataset
and computational intensity.  An additional script is provided which can
generate a job script for SLURM as well as the parameter file.  To generate
these files, ::

    python bin/create_nextflow_job.py generatessn auto --filter-min-val 23 --ssn-name ssn.xgmml --ssn-title "SSN Title" --est-output-dir est_results/ --efi-config efi.config --efi-db efi_202406 --nextflow-config slurm.config

In addition to the ``params.yml`` seen above, this will generate a SLURM job
submission script called ``run_nextflow.sh`` which can be started by running
``sbatch run_nextflow.sh``.

Stages
----------
.. toctree::
    :maxdepth: 1

    filter/index.rst

