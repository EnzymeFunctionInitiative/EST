#!/bin/bash

set -e

# def control functions
function ctrl_c() {
    echo "Stopping all tests"
    exit 0
}
trap ctrl_c SIGINT

# rough test to see if we are in repo root
if [[ ! -e pipelines/generatessn/generatessn.nf || ! -e pipelines/est/est.nf ]]; then
    echo "Run this script from the repository root"
    exit 1
fi

if [[ $# -ne 1 ]]; then
    CONFIG_FILE="docker.config"
else
    CONFIG_FILE=$1
fi

echo "Using $CONFIG_FILE config files for processes"

# if $TEST_RESULTS_DIR not defined already then set to default path
if [[ -z ${TEST_RESULTS_DIR} ]]; then
    TEST_RESULTS_DIR=tests/test_results
fi

if [[ ! -d $TEST_RESULTS_DIR ]]; then 
    mkdir -p $TEST_RESULTS_DIR
fi
echo "Test results will be written in $TEST_RESULTS_DIR"

set +e

if [[ -z ${EFI_CONFIG_FILE+1} || -z ${EFI_DB_NAME+1} || -z ${EFI_FASTA_DB+1} || -z ${EFI_TEST_ACC_FILE+1} || -z ${EFI_TEST_FASTA_FILE+1} || -z ${EFI_TEST_BLAST_SEQ+1} || -z ${EFI_TEST_ENV+1} || -z ${EFI_TEST_FAMILY_ID+1} ]]; then
    echo "Test environment variables not found, please run 'source tests/test_env.sh mysql' or 'source tests/test_env.sh sqlite'"
    exit 1
elif [[ "$EFI_TEST_ENV" != "mysql" && ! -d "$EFI_TEST_DATA_DIR" ]]; then
    echo "Test data directory not found, attempting to download"
    test_data_dir="tests/test_data/smalldata"
    mkdir -p $test_data_dir
    curl -o $test_data_dir/data.tar.gz https://efi.igb.illinois.edu/downloads/sample_data/kb_test_all.tar.gz
    tar xzf $test_data_dir/data.tar.gz -C $test_data_dir
    echo "[database]" > $test_data_dir/efi.config
    echo "dbi=sqlite" >> $test_data_dir/efi.config
fi

#bash "tests/modules/05_colorssn_uniprot.sh" $TEST_RESULTS_DIR $CONFIG_FILE
#exit
for file in $(ls tests/modules|grep '\.sh$'); do
    echo "================================================================================"
    echo "Executing tests in '$file'"
    bash "tests/modules/$file" $TEST_RESULTS_DIR $CONFIG_FILE
    if [[ $? -eq 0 ]]; then
	echo "Tests in '$file' passed"
    fi
done;

