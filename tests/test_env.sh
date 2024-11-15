#!/bin/bash
# usage: source tests/test_env.sh [[--db-type mysql|sqlite]] [[--data-dir /path/to/data/directory]]
# Optional inputs:
#	--db-type, accepted values are mysql or sqlite
#	--data-dir, a local or global path where the sample data will be untarred into

# loop over input arguments
for (( index=1; index <= "$#"; index++ ))
do
	# get the next argument's index
	idx=$((index+1))
	# check if this argument matches a parameter string
	if [[ ${!index} == "--db-type" ]]
	then
		# grab the value of the next argument and save it in a var
		db_type="${!idx}"
		echo "Using $db_type as the test environment"
	# check if this argument matches a parameter string
	elif [[ ${!index} == "--data-dir" ]]
	then
		# grab the value of the next argument and save it in a var
		data_dir="${!idx}"
		echo "Testing input data will be untarred in $data_dir"
	fi
done

# apply default values if input arguments are not given
if [[ -z $db_type ]]
then
	db_type="sqlite"
fi

if [[ -z $data_dir ]]
then
	data_dir="tests/test_data"
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

export EFI_TEST_DATA_DIR=$DATA_DIR
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

