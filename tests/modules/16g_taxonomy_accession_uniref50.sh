#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2

self=$(basename "$0" .sh)
OUTPUT_DIR="$TEST_RESULTS_DIR/$self"

rm -rf $OUTPUT_DIR

./bin/create_taxonomy_nextflow_params.py accessions --output-dir $OUTPUT_DIR --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME --fasta-db $EFI_FASTA_DB --input-file $EFI_TEST_ACC_FILE --sequence-version uniref50 --nextflow-config $CONFIG_FILE
bash $OUTPUT_DIR/run_nextflow.sh

