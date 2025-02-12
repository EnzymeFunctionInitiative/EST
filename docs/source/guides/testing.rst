Testing
=======
This repository includes several basic validation tests to confirm that the
completed EFI pipelines execute without errors. If the pipeline is an EST workflow
(e.g. BLAST, family, accession, FASTA), then the SSN generation pipeline is
also run using a parameter file generated on "auto" mode (see
``bin/create_generatessn_nextflow_params.py``).

The tests use a simple dataset that includes all elements of data needed for
the EFI tools with a fraction of the number of sequences in the full EFI
databases. By default, this test data is downloaded into a directory inside
of the repository. Similarly, results from the tests are written to a directory 
inside the repository by default. To run tests using the simple dataset with 
Docker, run the following commands from the EST repository's root directory: ::

    chmod +x ./tests/runtests.sh ./tests/test_env.sh
    source ./tests/test_env.sh
    ./tests/runtests.sh docker.config

To instead run tests using Singularity, replace the last line from above with: ::

    ./tests/runtests.sh singularity.config

Test Environment Setup
----------------------
The ``test_env.sh`` script defines certain environment variables that are used 
within the ``runtests.sh`` and test module scripts. It has command line arguments
that control the type of SQL database management system used to run the 
analysis queries as well as paths to where test input and output files will be 
saved. 

The usage of the ``test_env.sh`` script is printed by running: ::

    ./tests/test_env.sh --help

which returns: ::

    Usage information for test_env.sh:
    Must be in the EST root directory. 
    To run: source tests/test_env.sh [[--db-type mysql|sqlite]] [[--data-dir /path]] [[--results-dir /path]] [[--help]]
    Optional inputs:
    	--db-type, accepted values are mysql or sqlite, default: sqlite
    	--data-dir, a global path where the sample data will be untarred into, 
    		    default: tests/test_data
    	--results-dir, a global path where the results from the test suite will 
    		       be written, default: tests/test_results
    	--help, prints this usage information
    
All command line arguments for this script are optional. 

``--db-type`` argument
~~~~~~~~~~~~~~~~~~~~
The ``--db-type`` argument currently accepts any value but, if given an 
unexpected value, will fallback to being assigned the default value of "sqlite".
The accepted values are ``sqlite`` or ``mysql``. Giving a value of "mysql"
 expects that the full EFI database files are stored locally.

``--data-dir`` argument
~~~~~~~~~~~~~~~~~~~~
The ``--data-dir`` argument currently accepts any value but expects a global 
path to a directory where the sample data will be written to. Alternatively, if
this directory already exists, the downloading and untar'ing of the sample data 
will be skipped.

``--results-dir`` argument
~~~~~~~~~~~~~~~~~~~~
The ``--results-dir`` argument currently accepts any value but expects a global
path to a directory where the testing results will be written to. If this 
directory already exists, the results files will be overwritten upon running 
the ``runtests.sh`` script. 

Examples:
~~~~~~~~~
If you would like to download the sample data in the default location 
(``tests/test_data``) but want results to be written to a EST-external 
directory: ::

    # from the EST root directory
    source ./tests/test_env.sh --results-dir ~/efi_testing/run1/
    ./tests/runtests.sh docker.config

Or, if the sample data has already been untar'd in a EST-external directory 
(e.g. ``~/efi_testing/sample_data/``): ::

    # from the EST root directory
    source ./tests/test_env.sh --data-dir ~/efi_testing/sample_data/ --results-dir ~/efi_testing/run2/
    ./tests/runtests.sh docker.config

These examples both assume that the EFI-EST docker container is used. See below
if a different container system or job submission method is used.

Nextflow Configurations
-----------------------

Nextflow configuration files must be passed as positional arguments to the 
``./tests/runtests.sh`` and module testing scripts (see below).
These configurations exist for various environments such as running the 
pipelines on PBS-Torque- or Slurm-based clusters as well as using Docker or 
Singularity containers. Configuration files can be found in ``conf/<workflow>`` 
where ``workflow`` corresponds to one of the pipelines in ``pipelines/``.

Individual Tests
----------------

The commands above will run all of the ``*.sh`` files in the ``./tests/modules/``
directory. The scripts have a numeric prefix so that they are run in succession
each time for reproducibility. After running the ``source ./tests/test_env.sh`` 
script, individual tests can be run with the following command: ::

    ./tests/modules/<script> $EFI_TEST_RESULTS_DIR <nextflow_config>

where ``script`` is one of the ``##_module_name.sh`` files in the
``./tests/modules/`` directory. An example might be: ::

    ./tests/modules/01_est_sequence_blast.sh $EFI_TEST_RESULTS_DIR singularity.config

