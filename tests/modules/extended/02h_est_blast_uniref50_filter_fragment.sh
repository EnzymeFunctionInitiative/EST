#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2

self=$(basename "$0" .sh)
OUTPUT_DIR="$TEST_RESULTS_DIR/$self"

rm -rf $OUTPUT_DIR

./bin/create_est_nextflow_params.py blast --output-dir $OUTPUT_DIR --efi-config $EFI_CONFIG_FILE --fasta-db $EFI_FASTA_DB --efi-db $EFI_DB_NAME --input-file $EFI_TEST_BLAST_SEQ --nextflow-config $CONFIG_FILE --import-blast-fasta-db $EFI_BLAST_IMPORT_FASTA_DB --sequence-version uniref50 --filter fragments
bash $OUTPUT_DIR/run_nextflow.sh

./bin/create_generatessn_nextflow_params.py auto --filter-min-val 87 --ssn-name testssn --job-name test-ssn --est-output-dir $OUTPUT_DIR --nextflow-config $CONFIG_FILE --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME
bash $OUTPUT_DIR/ssn/run_nextflow.sh

