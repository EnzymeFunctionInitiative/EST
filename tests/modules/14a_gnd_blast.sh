#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2

self=$(basename "$0" .sh)
OUTPUT_DIR="$TEST_RESULTS_DIR/$self"

rm -rf $OUTPUT_DIR

./bin/create_gnd_nextflow_params.py --output-dir $OUTPUT_DIR --import-mode blast --import-blast-fasta-db $EFI_FASTA_DB --import-blast-num-matches 200 --import-blast-evalue 5 --input-file $EFI_TEST_BLAST_SEQ --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME --nextflow-config $CONFIG_FILE
bash $OUTPUT_DIR/run_nextflow.sh

