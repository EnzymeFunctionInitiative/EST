
# Quick Start:
Starting from the EST root directory, run the commands below to run the default testing suite.

```bash
chmod +x tests/runtests.sh tests/test_env.sh
source ./tests/test_env.sh
./tests/runtests.sh test.docker.conf
```
This will download the testing dataset in `tests/test_data/`. Results of the tests will be written in `tests/test_results/`. 

# Set up test environment

The `test_env.sh` script defines certain environment variables that are used within the `runtests.sh` and test module scripts.
It has command line arguments that can be included to control what type of SQL database management system will be used for the analysis queries as well as paths to where test input and output files will be saved. 
Specifically, the usage of the `test_env.sh` script can be seen by running `./tests/test_env.sh --help`, returning:

```
usage: source tests/test_env.sh [[--db-type mysql|sqlite]] [[--data-dir /path]] [[--results-dir /path]] [[--help]]
Optional inputs:
	--db-type, accepted values are mysql or sqlite
	--data-dir, a local or global path where the sample data will be 
		    untarred into
	--results-dir, a local or global path where the results from the test 
		       suite will be written
	--help, prints usage information
```

As demonstrated in the quick start section all of the command line arguments are optional. 

### `--db-type` argument
The `--db-type` argument currently accepts any values but will only run the tests successfully if given "sqlite". 
Giving a value of "mysql" requires more development/testing.
From the previous version of this README: 

> Assuming that the MySQL dataset and database have been setup and BLAST database files have been installed in `tests/test_data/mysql`, the MySQL environment can be set up by running `source tests/test_env.sh mysql`.  To use the `smalldata` test case based on SQLite, run `source tests/test_env.sh`.

### `--data-dir` argument
The `--data-dir` argument currently accepts any values but expects a global or local path to a directory where the sample data will be written to. 
Alternatively, if this directory already exists and contains the sample data, the downloading and untar'ing of the sample data will be skipped.  

### `--results-dir` argument
The `--results-dir` argument currently accepts any values but expects a global or local path to a directory where the testing results will be written to.
If this directory already exists, the results files will be overwritten upon running the `runtests.sh` script. 

# Examples:
If you would like to download the sample data in the default location (`tests/test_data`) but want results to be written to a EST-external directory: 
```
# from the EST root directory
source ./tests/test_env.sh --results-dir ~/efi_testing/run1/
./tests/runtests.sh test.docker.config
```

Or, if the sample data has already been untar'd in a EST-external directory (e.g. `~/efi_testing/sample_data/`): 
```
# from the EST root directory
source ./tests/test_env.sh --data-dir ~/efi_testing/sample_data/ --results-dir ~/efi_testing/run2/
./tests/runtests.sh test.docker.config
```


