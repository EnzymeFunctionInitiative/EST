#!/bin/bash

set -e

TEST_RESULTS_DIR=test_results

if [[ ! -e ssn.nf || ! -e est.nf ]]; then
    echo "Run this script from the repository root"
    exit 1
fi

if [[ ! -e smalldata || ! -d smalldata ]]; then
    echo "Test data directory not found, attempting to download"
    mkdir smalldata
    curl -o smalldata/data.tar.gz https://efi.igb.illinois.edu/downloads/sample_data/kb_test_all.tar.gz
    tar xzf smalldata/data.tar.gz -C smalldata/
    echo "[database]" > smalldata/efi.config
    echo "dbi=sqlite" >> smalldata/efi.config
fi

source efi-env/bin/activate

rm -rf $TEST_RESULTS_DIR
mkdir $TEST_RESULTS_DIR

set +e

for file in $(ls tests/modules); do
    echo "================================================================================"
    echo "Executing test in '$file'"
    bash "tests/modules/$file" $TEST_RESULTS_DIR
done;
