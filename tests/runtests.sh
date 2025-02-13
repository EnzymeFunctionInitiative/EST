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

if [[ -z "$EFI_CONFIG_FILE" || -z "$EFI_DB_NAME" || -z "$EFI_FASTA_DB" ]]; then
    echo "Test environment variables not found, please run 'source tests/test_env.sh'"
    exit 1
fi

if [[ ! -d $EFI_TEST_RESULTS_DIR ]]; then 
    mkdir -p $EFI_TEST_RESULTS_DIR
fi

set +e

for file in $(ls tests/modules|grep '\.sh$'); do
    echo "================================================================================"
    echo "Executing tests in '$file'"
    bash "tests/modules/$file" $EFI_TEST_RESULTS_DIR $CONFIG_FILE
    if [[ $? -eq 0 ]]; then
	    echo "Tests in '$file' passed"
    fi
done;

