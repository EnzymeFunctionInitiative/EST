#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2
NXF_GNT_CONFIG_FILE="conf/gnt/$CONFIG_FILE"

OUTPUT_DIR="$TEST_RESULTS_DIR/test_results_gnt"

rm -rf $OUTPUT_DIR

ssn_file=$EFI_TEST_SSN_UNIPROT
if [[ ! -e "$ssn_file" ]]; then
    echo "Missing ssn file"
    exit 1
fi

./bin/create_gnt_nextflow_params.py --final-output-dir $OUTPUT_DIR --ssn-input $ssn_file --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME --fasta-db $EFI_FASTA_DB

nextflow -C $NXF_GNT_CONFIG_FILE run pipelines/gnt/gnt.nf -params-file $OUTPUT_DIR/params.yml

