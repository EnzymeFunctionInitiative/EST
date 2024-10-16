Testing
=======
This repository include several basic validation tests to confirm that the
completed pipelines execute without errors. If the pipeline is an EST workflow
(e.g. BLAST, family, accession, FASTA), then the SSN generation pipeline is
also run using a parameter file which has been generated on "auto" mode (see
``bin/create_generatessn_nextflow_params.py``).

The tests use a simple dataset that includes all elements of data needed for
the EFI tools with a fraction of the number of sequences in the full EFI
databases. By default the test data is downloaded into a directory inside
of the repository; issues may arise with Docker or Singularity Nextflow
configurations that will not appear when using the tools when actual data is used.
To run tests using the simple dataset with Docker, run the following command: ::

    ./tests/runtests.sh test.docker.config

To run tests using the simple dataset with Singularity, run the following
command: ::

    ./tests/runtests.sh test.singularity.config

Nextflow Configurations
-----------------------

Nextflow configuration files must be passed as positional arguments.
Configurations exist for various environments, which include running on
PBS-Torque- or Slurm-based clusters, and using Docker or Singularity
containers. Configuration files can be found in ``conf/<workflow>`` where
``workflow`` corresponds to one of the pipelines in ``pipelines/``.

Configuration files beginning with ``test.`` are designed to be run using the
simple dataset detailed above. If using a test dataset that is outside of the
repository directory tree then the normal config file should be used (e.g.
``docker.config`` instead of ``test.docker.config``).

Individual Tests
----------------

The commands above will run all of the ``*.sh`` files in the ``./tests/modules/``
directory. The scripts have a numeric prefix so that they are run in succession
each time for reproducibility. Individual tests can be run with the following
command: ::

    ./tests/modules/<script> <results_dir> <nextflow_config>

where ``script`` is one of the ``##_module_name.sh`` files in the
``./tests/modules/`` directory. ``results_dir`` is usually ``test_results``.
An example might be: ::

    ./tests/modules/01_est_sequence_blast.sh test_results test.singularity.config

