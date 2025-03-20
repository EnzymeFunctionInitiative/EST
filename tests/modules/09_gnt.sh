#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2
NXF_GNT_CONFIG_FILE="conf/gnt/$CONFIG_FILE"

self=$(basename "$0" .sh)
OUTPUT_DIR="$TEST_RESULTS_DIR/$self"

rm -rf $OUTPUT_DIR

ssn_file=$EFI_TEST_SSN_UNIPROT
if [[ ! -e "$ssn_file" ]]; then
    echo "Missing ssn file"
    exit 1
fi

./bin/create_gnt_nextflow_params.py --output-dir $OUTPUT_DIR --ssn-input $ssn_file --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME --fasta-db $EFI_FASTA_DB --nextflow-config $NXF_GNT_CONFIG_FILE
bash $OUTPUT_DIR/run_nextflow.sh

