#!/bin/bash
set -e

if [[ ! -e "$EFI_TEST_SSN_COMPLETE_GRAPH" ]]; then
    echo "Test skipped; missing $EFI_TEST_SSN_COMPLETE_GRAPH"
    exit 0
fi

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2

self=$(basename "$0" .sh)
OUTPUT_DIR="$TEST_RESULTS_DIR/$self"

rm -rf $OUTPUT_DIR

./bin/create_conv_ratio_nextflow_params.py --output-dir $OUTPUT_DIR --ssn-input $EFI_TEST_SSN_COMPLETE_GRAPH --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME --fasta-db $EFI_FASTA_DB --nextflow-config $CONFIG_FILE --ascore 5
bash $OUTPUT_DIR/run_nextflow.sh

