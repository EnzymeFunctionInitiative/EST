#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2
NXF_EST_CONFIG_FILE="conf/est/$CONFIG_FILE"
NXF_SSN_CONFIG_FILE="conf/generatessn/$CONFIG_FILE"

self=$(basename "$0" .sh)
OUTPUT_DIR="$TEST_RESULTS_DIR/$self"

rm -rf $OUTPUT_DIR

family=$(<$EFI_TEST_FAMILY_ID)

./bin/create_est_nextflow_params.py fasta --output-dir $OUTPUT_DIR --efi-config $EFI_CONFIG_FILE --fasta-db $EFI_FASTA_DB --efi-db $EFI_DB_NAME --fasta-file $EFI_TEST_FASTA_FILE --nextflow-config $NXF_EST_CONFIG_FILE --families $family
bash $OUTPUT_DIR/run_nextflow.sh

./bin/create_generatessn_nextflow_params.py auto --filter-min-val 87 --ssn-name testssn --ssn-title test-ssn --est-output-dir $OUTPUT_DIR --nextflow-config $NXF_SSN_CONFIG_FILE --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME
bash $OUTPUT_DIR/ssn/run_nextflow.sh

