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

if [[ -z "$EFI_CONFIG_FILE" || -z "$EFI_DB_NAME" || -z "$EFI_FASTA_DB" || -z "$EFI_TEST_ACC_FILE" || -z "$EFI_TEST_FASTA_FILE" || -z "$EFI_TEST_BLAST_SEQ" || -z "$EFI_TEST_ENV" || -z "$EFI_TEST_FAMILY_ID" ]]; then
    echo "Test environment variables not found, please run 'source tests/test_env.sh'"
    exit 1
elif [[ "$EFI_TEST_ENV" != "mysql" && ! -d "$EFI_TEST_DATA_DIR" ]]; then
    echo "Test data directory not found, attempting to download"
    #test_data_dir="tests/test_data/smalldata"
    mkdir -p $EFI_TEST_DATA_DIR
    curl -o $EFI_TEST_DATA_DIR/data.tar.gz https://efi.igb.illinois.edu/downloads/sample_data/kb_test_all/kb_test_all.tar.gz
    tar xzf $EFI_TEST_DATA_DIR/data.tar.gz -C $EFI_TEST_DATA_DIR
    echo "[database]" > $EFI_TEST_DATA_DIR/efi.config
    echo "dbi=sqlite" >> $EFI_TEST_DATA_DIR/efi.config
fi

if [[ ! -d $EFI_TEST_RESULTS_DIR ]]; then 
    mkdir -p $EFI_TEST_RESULTS_DIR
fi

set +e

bash "tests/modules/05_colorssn_uniprot.sh" $EFI_TEST_RESULTS_DIR $CONFIG_FILE
exit
for file in $(ls tests/modules|grep '\.sh$'); do
    echo "================================================================================"
    echo "Executing tests in '$file'"
    bash "tests/modules/$file" $EFI_TEST_RESULTS_DIR $CONFIG_FILE
    if [[ $? -eq 0 ]]; then
	echo "Tests in '$file' passed"
    fi
done;

