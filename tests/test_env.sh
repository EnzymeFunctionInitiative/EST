#!/bin/bash

# starting fresh
db_type=
data_dir=
results_dir=
db_name=
fasta_db=
blast_import_fasta_db=
config_file=
EFI_DB_NAME=
EFI_TEST_ENV=
EFI_TEST_DATA_DIR=
EFI_CONFIG_FILE=
EFI_FASTA_DB=
EFI_TEST_ACC_FILE=
EFI_TEST_FASTA_FILE=
EFI_TEST_BLAST_SEQ=
EFI_TEST_FAMILY_ID=
EFI_TEST_SSN_UNIPROT=
EFI_TEST_SSN_UNIREF90=
EFI_TEST_SSN_UNIREF50=
EFI_TEST_SSN_REPNODE=
EFI_TEST_RESULTS_DIR=

# loop over input arguments
for (( index=1; index <= $#; index++ ))
do
	# get the next argument's index
	idx=$((index+1))
	# check if this argument matches a parameter string
	if [[ ${!index} == '--help' ]]; then
		echo "Usage: source tests/test_env.sh [--db-type mysql|sqlite --data-dir /path --results-dir /path]
    [--db-name database_name_or_path --fasta-db blast_db --config-file /path/file]

    Description:
        Sets the environment variables necessary for running tests on the EFI
        tools. This script must be run from the EST root directory.

    Options:
        --db-type       database interface to use, mysql or sqlite
        --data-dir      path to the test dataset
        --results-dir   path to an output directory to store results into
        --db-name       name of the EFI database to use (path to .sqlite file
                        in the case that the db-type is sqlite); test datasets
                        contain a default database, and this option can be used
                        to connect tests to external, large EFI databases
        --fasta-db      path to a BLAST database that is used to retrieve
                        sequences for computations; test datasets contain a
                        default database, and this option can be used to
                        connect tests to external, large BLAST databases used
                        in the full EFI toolset
        --blast-import-fasta-db
                        path to a BLAST database that is used to determine which
                        IDs are to be used in the computation; if not specified
                        then the test UniRef50 database is used
        --config-file   path to a configuration file used by the EFI tools to
                        connect to a database; test datasets contain a default
                        configuration file, and this option can be used to
                        connect tests to external databases
        --help          prints this message
"
		return
	# check if this argument matches a parameter string
	elif [[ ${!index} == "--db-type" ]]; then
		# grab the value of the next argument and save it in a var
		db_type="${!idx}"
		echo "Using $db_type as the test environment"
	# check if this argument matches a parameter string
	elif [[ ${!index} == "--data-dir" ]]; then
		# grab the value of the next argument and save it in a var
		data_dir="${!idx}"
		echo "Using test input data from $data_dir"
	# check if this argument matches a parameter string
	elif [[ ${!index} == "--results-dir" ]]; then
		# grab the value of the next argument and save it in a var
		results_dir="${!idx}"
		echo "Testing results will be written in $results_dir"
	# manually specify the EFI database name/path
	elif [[ ${!index} == "--db-name" ]]; then
		db_name="${!idx}"
		echo "Using $db_name for the EFI database"
	# manually specify the FASTA database path
	elif [[ ${!index} == "--fasta-db" ]]; then
		fasta_db="${!idx}"
		echo "Using $fasta_db as the FASTA database path"
	elif [[ ${!index} == "--blast-import-fasta-db" ]]; then
		blast_import_fasta_db="${!idx}"
		echo "Using $blast_import_fasta_db as the UniRef BLAST import FASTA database path"
	# manually specify the configuration file
	elif [[ ${!index} == "--config-file" ]]; then
		config_file="${!idx}"
		echo "Using $config_file as the config file for database connections"
	fi
done

# apply default values if input arguments are not given
if [[ -z "$db_type" ]]; then
	db_type="sqlite"
fi

if [[ -z "$data_dir" ]]; then
	data_dir="$(pwd)/tests/test_data"
fi

if [[ -z "$results_dir" ]]; then
	results_dir="$(pwd)/tests/test_results"
fi

# creating the necessary environment variables
if [[ $db_type == "mysql" ]]; then
    DATA_DIR="$data_dir/mysql"
    if [[ -z "$db_name" ]]; then
        db_name="efi_db"
    fi
    export EFI_TEST_ENV="mysql"
else
    DATA_DIR="$data_dir/sqlite"
    if [[ -z "$db_name" ]]; then
        db_name="$DATA_DIR/efi_db.sqlite"
    fi
    export EFI_TEST_ENV="sqlite"
fi

# data must be downloaded and unpacked first
if [[ ! -d "$DATA_DIR" ]]; then
    echo "Test data directory $DATA_DIR does not exist; download a sample dataset before running this script"
    return
fi

# set the default configuration file if one was not provided by the user
if [[ -z "$config_file" || ! -f "$config_file" ]]; then
    config_file="$DATA_DIR/efi.config"
fi

# set the default FASTA/BLAST db if one was not provided by the user
if [[ -z "$fasta_db" ]]; then
    fasta_db="$DATA_DIR/blastdb/combined.fasta"
fi

if [[ -z "$blast_import_fasta_db" ]]; then
    blast_import_fasta_db="$DATA_DIR/blastdb/uniref50.fasta"
fi


export EFI_DATA_DIR=$data_dir
export EFI_CONFIG_FILE=$config_file
export EFI_DB_NAME=$db_name
export EFI_FASTA_DB=$fasta_db
export EFI_BLAST_IMPORT_FASTA_DB=$blast_import_fasta_db
export EFI_TEST_ACC_FILE="$DATA_DIR/accession_test.txt"
export EFI_TEST_FASTA_FILE="$DATA_DIR/fasta_test.fasta"
export EFI_TEST_BLAST_SEQ="$DATA_DIR/blast_query.fa"
export EFI_TEST_FAMILY_ID="$DATA_DIR/family_id.txt"
export EFI_TEST_SSN_UNIPROT="$DATA_DIR/ssn.xgmml.zip"
export EFI_TEST_SSN_UNIREF90="$DATA_DIR/ssn_uniref90.xgmml"
export EFI_TEST_SSN_UNIREF50="$DATA_DIR/ssn_uniref50.xgmml"
export EFI_TEST_SSN_REPNODE="$DATA_DIR/ssn_repnode70.xgmml"
export EFI_TEST_ID_LIST_FILE="$DATA_DIR/gnd_id_list.txt"
export EFI_TEST_RESULTS_DIR=$results_dir

