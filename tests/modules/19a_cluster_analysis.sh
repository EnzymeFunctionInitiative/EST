#!/bin/bash
set -e

if [[ ! -e "$EFI_TEST_SSN_UNIPROT" ]]; then
    echo "Test skipped; missing $EFI_TEST_SSN_UNIPROT"
    exit 0
fi

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2

self=$(basename "$0" .sh)
OUTPUT_DIR="$TEST_RESULTS_DIR/$self"

rm -rf $OUTPUT_DIR

./bin/create_clusteranalysis_nextflow_params.py --output-dir $OUTPUT_DIR --ssn-input $EFI_TEST_SSN_UNIPROT --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME --fasta-db $EFI_FASTA_DB --nextflow-config $CONFIG_FILE \
    --weblogo \
    --hmms \
    --length-histo \
    --compute-cons-res \
    --residues C,A \
    --pid-thresholds 50,100
bash $OUTPUT_DIR/run_nextflow.sh

