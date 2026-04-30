#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2

self=$(basename "$0" .sh)
OUTPUT_DIR="$TEST_RESULTS_DIR/$self"

rm -rf $OUTPUT_DIR

family=$(<$EFI_TEST_FAMILY_ID)

./bin/create_taxonomy_nextflow_params.py family --output-dir $OUTPUT_DIR --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME --fasta-db $EFI_FASTA_DB --families $family --sequence-version uniprot --nextflow-config $CONFIG_FILE --filter predef-file=$PWD/pipelines/shared/assets/predefined_taxonomy_filters.yml --filter predef-filter=bacteria
bash $OUTPUT_DIR/run_nextflow.sh

