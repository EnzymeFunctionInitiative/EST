#!/bin/bash

set -e

function ctrl_c() {
    echo "Stopping all tests"
    exit 0
}

trap ctrl_c SIGINT

TEST_RESULTS_DIR=test_results

# rough test to see if we are in repo root
if [[ ! -e pipelines/generatessn/generatessn.nf || ! -e pipelines/est/est.nf ]]; then
    echo "Run this script from the repository root"
    exit 1
fi

if [ $# -ne 2 ]; then
    NXF_EST_CONFIG_FILE='conf/est/docker.config'
    NXF_SSN_CONFIG_FILE='conf/generatessn/docker.config'
else
    NXF_EST_CONFIG_FILE=$1
    NXF_SSN_CONFIG_FILE=$2
fi

echo "NXF_EST_CONFIG is $NXF_EST_CONFIG_FILE"
echo "NXF_SSN_CONFIG is $NXF_SSN_CONFIG_FILE"

if [[ ! -e smalldata || ! -d smalldata ]]; then
    echo "Test data directory not found, attempting to download"
    mkdir smalldata
    curl -o smalldata/data.tar.gz https://efi.igb.illinois.edu/downloads/sample_data/kb_test_all.tar.gz
    tar xzf smalldata/data.tar.gz -C smalldata/
    echo "[database]" > smalldata/efi.config
    echo "dbi=sqlite" >> smalldata/efi.config
fi

rm -rf $TEST_RESULTS_DIR
mkdir $TEST_RESULTS_DIR

set +e

for file in $(ls tests/modules); do
    echo "================================================================================"
    echo "Executing test in '$file'"
    bash "tests/modules/$file" $TEST_RESULTS_DIR $NXF_EST_CONFIG_FILE $NXF_SSN_CONFIG_FILE
done;
