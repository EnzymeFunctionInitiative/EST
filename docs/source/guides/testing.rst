Testing
=======
This repository include several basic validation tests to confirm that the
pipelines execute without errors. There is one test per import method (4 total).
These tests executes the EST pipeline and then the SSN generation pipeline using a
parameter file which has been generated on "auto" mode (see
`create_generatessn_nextflow_params.py`).

To execute all tests with docker configurations, run the following command: ::

    ./tests/runtests.sh

To execute an individual import mode test, execute ::

    ./tests/modules/est_<mode>.sh <results_dir> <est_nextflow_config> <ssn_nextflow_config>

where ``mode`` is one of ``sequence_blast``, ``family``, ``fasta``, or ``accession``.
``results_dir`` is usually ``test_results``. Nextflow configuration files for both
pipelines must be passed as positional arguments. Configuration files can be
found in ``conf/``.


Custom Configuration
--------------------

By default, the test scripts use ``conf/<pipeline>/docker.config``. The test
runner accepts two positional arguments, the first will be the config used for
EST and the second will be used for the SSN generation pipeline. To use custom
configuration files, ::
    
    ./tests/runtests.sh conf/est/<config_file> conf/ssn/<config_file>
