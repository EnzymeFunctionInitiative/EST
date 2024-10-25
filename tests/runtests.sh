#!/bin/bash

# TO DO:
# add tests for job script creation (issue 63)
# add tests for results check (no issue yet)

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

if [ $# -ne 1 ]; then
    CONFIG_FILE="docker.config"
else
    CONFIG_FILE=$1
fi

echo "Using $CONFIG_FILE config files for processes"

TEST_RESULTS_DIR=/tmp/nextflow/efi_tests
if [ ! -d $TEST_RESULTS_DIR ]; then 
    mkdir -p $TEST_RESULTS_DIR
fi

set +e

if [[ -z ${EFI_CONFIG_FILE+1} || -z ${EFI_DB_NAME+1} || -z ${EFI_FASTA_DB+1} || -z ${EFI_TEST_ACC_FILE+1} || -z ${EFI_TEST_FASTA_FILE+1} || -z ${EFI_TEST_BLAST_SEQ+1} || -z ${EFI_TEST_ENV+1} || -z ${EFI_TEST_FAMILY_ID+1} ]];
then
    echo "Test environment variables not found, please source tests/test_env.sh mysql or sqlite"
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
    tmp_dir="$(mktemp -d $TEST_RESULTS_DIR/XXXXXX)"
    echo "Temporary directories/files will be written in '$tmp_dir'"
    bash "tests/modules/$file" $tmp_dir $CONFIG_FILE 2> >(tee $tmp_dir/err.log >&2)
    if [[ $? -eq 0 ]]; then
	echo "Tests in '$file' passed"
	echo "Cleaning up tmp dir '$tmp_dir'"
        rm -rf $tmp_dir
    fi
done;

