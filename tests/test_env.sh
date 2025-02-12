#!/bin/bash
# usage: source tests/test_env.sh [[--db-type mysql|sqlite]] [[--data-dir /path]] [[--results-dir /path]] [[--help]]
# Optional inputs:
#	--db-type, accepted values are mysql or sqlite
#	--data-dir, a local or global path where the sample data will be 
#		    untarred into
#	--results-dir, a local or global path where the results from the test 
#		       suite will be written
#	--help, prints usage information

# starting fresh
db_type=
data_dir=
results_dir=
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
		echo "Usage information for test_env.sh:
Must be in the EST root directory. 
To run: source tests/test_env.sh [[--db-type mysql|sqlite]] [[--data-dir /path]] [[--results-dir /path]] [[--help]]
Optional inputs:
	--db-type, accepted values are mysql or sqlite, default: sqlite
	--data-dir, a global path where the sample data will be untarred into, 
		    default: tests/test_data
	--results-dir, a global path where the results from the test suite will 
		       be written, default: tests/test_results
	--help, prints this usage information"
		exit
	# check if this argument matches a parameter string
	elif [[ ${!index} == "--db-type" ]]; then
		# grab the value of the next argument and save it in a var
		db_type="${!idx}"
		echo "Using $db_type as the test environment"
	# check if this argument matches a parameter string
	elif [[ ${!index} == "--data-dir" ]]; then
		# grab the value of the next argument and save it in a var
		data_dir="${!idx}"
		echo "Testing input data will be untarred in $data_dir"
	# check if this argument matches a parameter string
	elif [[ ${!index} == "--results-dir" ]]; then
		# grab the value of the next argument and save it in a var
		results_dir="${!idx}"
		echo "Testing results will be written in $results_dir"
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
    export EFI_DB_NAME="efi_db"
    export EFI_TEST_ENV="mysql"
else
    DATA_DIR="$data_dir/smalldata"
    export EFI_DB_NAME="$DATA_DIR/efi_db.sqlite"
    export EFI_TEST_ENV="sqlite"
fi

export EFI_DATA_DIR=$data_dir
export EFI_CONFIG_FILE="$DATA_DIR/efi.config"
export EFI_FASTA_DB="$DATA_DIR/blastdb/combined.fasta"
export EFI_TEST_ACC_FILE="$DATA_DIR/accession_test.txt"
export EFI_TEST_FASTA_FILE="$DATA_DIR/fasta_test.fasta"
export EFI_TEST_BLAST_SEQ="$DATA_DIR/blast_query.fa"
export EFI_TEST_FAMILY_ID="$DATA_DIR/family_id.txt"
export EFI_TEST_SSN_UNIPROT="$DATA_DIR/ssn.xgmml"
export EFI_TEST_SSN_UNIREF90="$DATA_DIR/ssn_uniref90.xgmml"
export EFI_TEST_SSN_UNIREF50="$DATA_DIR/ssn_uniref50.xgmml"
export EFI_TEST_SSN_REPNODE="$DATA_DIR/ssn_repnode70.xgmml"
export EFI_TEST_RESULTS_DIR=$results_dir

