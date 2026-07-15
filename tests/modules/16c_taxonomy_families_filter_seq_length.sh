#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2

self=$(basename "$0" .sh)
OUTPUT_DIR="$TEST_RESULTS_DIR/$self"

rm -rf $OUTPUT_DIR

family=$(<$EFI_TEST_FAMILY_ID)

./bin/create_taxonomy_nextflow_params.py family --output-dir $OUTPUT_DIR --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME --fasta-db $EFI_FASTA_DB --families $family --sequence-version uniprot --nextflow-config $CONFIG_FILE --filter min-seq-length=10 --filter max-seq-length=150
bash $OUTPUT_DIR/run_nextflow.sh

