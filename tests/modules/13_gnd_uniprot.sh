#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2
NXF_GND_CONFIG_FILE="conf/gnd/$CONFIG_FILE"

self=$(basename "$0" .sh)
OUTPUT_DIR="$TEST_RESULTS_DIR/$self"

rm -rf $OUTPUT_DIR

./bin/create_gnd_nextflow_params.py --output-dir $OUTPUT_DIR --cluster-id-map $EFI_TEST_ID_LIST_FILE --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME --nextflow-config $NXF_GND_CONFIG_FILE
bash $OUTPUT_DIR/run_nextflow.sh

