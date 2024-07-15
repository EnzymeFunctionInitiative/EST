Testing
=======
This repository include several basic validation tests to confirm that the
pipelines execute without errors. There is one test per import method (4 total).
These tests executes the EST pipeline and then the SSN pipeline using a
parameter file which has been generated on "auto" mode (see
`create_ssn_nextflow_params.py`).

To execute all tests, run the following command: ::

    ./tests/runtests.sh

To execute and individual import mode test, execute ::

    ./tests/modules/est_<mode>.sh <results_dir>

where `mode` is one of `sequence_blast`, `family`, `fasta`, or `accession`.
`results_dir` is usually `test_results`.


Custom Configuration
--------------------

By default, the test scripts use ``conf/docker.config``. To use an alternative
configuration file, pass it as a positional argument to the test runner script ::
    
    ./tests/runtests.sh conf/<config_file>

or the individual test script ::

    ./tests/modules/est_<mode>.sh <results_dir> conf/<config_file>