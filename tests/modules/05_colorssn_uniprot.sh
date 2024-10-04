#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2
NXF_COLORSSN_CONFIG_FILE="conf/colorssn/$CONFIG_FILE"

OUTPUT_DIR="$TEST_RESULTS_DIR/test_results_colorssn_uniprot"

rm -rf $OUTPUT_DIR

ssn_file=$EFI_TEST_SSN_UNIPROT
if [[ ! -e "$ssn_file" ]]; then
    ssn_file="$TEST_RESULTS_DIR/test_results_accession/ssn/full_ssn.xgmml"
fi
if [[ ! -e "$ssn_file" ]]; then
    exit 1
fi

./bin/create_colorssn_nextflow_params.py --final-output-dir $OUTPUT_DIR --ssn-input $ssn_file --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME --fasta-db $EFI_FASTA_DB

nextflow -C $NXF_COLORSSN_CONFIG_FILE run pipelines/colorssn/colorssn.nf -params-file $OUTPUT_DIR/params.yml

