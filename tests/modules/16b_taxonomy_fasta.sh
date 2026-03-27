#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2

self=$(basename "$0" .sh)
OUTPUT_DIR="$TEST_RESULTS_DIR/$self"

rm -rf $OUTPUT_DIR

./bin/create_taxonomy_nextflow_params.py fasta --output-dir $OUTPUT_DIR --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME --input-file $EFI_TEST_FASTA_FILE --nextflow-config $CONFIG_FILE
bash $OUTPUT_DIR/run_nextflow.sh

