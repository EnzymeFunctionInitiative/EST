#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2

self=$(basename "$0" .sh)
OUTPUT_DIR="$TEST_RESULTS_DIR/$self"

rm -rf $OUTPUT_DIR

./bin/create_gnd_nextflow_params.py --output-dir $OUTPUT_DIR --import-mode accessions --input-file $EFI_TEST_ID_LIST_FILE --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME --nextflow-config $CONFIG_FILE --sequence-version uniref50
bash $OUTPUT_DIR/run_nextflow.sh

