#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2
NXF_COLORSSN_CONFIG_FILE="conf/colorssn/$CONFIG_FILE"

OUTPUT_DIR="$TEST_RESULTS_DIR/test_results_colorssn"

rm -rf $OUTPUT_DIR

./bin/create_colorssn_nextflow_params.py --final-output-dir $OUTPUT_DIR --ssn-input "$TEST_RESULTS_DIR/test_results_accession/ssn/full_ssn.xgmml" --efi-config smalldata/efi.config --efi-db smalldata/efi_db.sqlite --fasta-db smalldata/blastdb/combined

nextflow -C $NXF_COLORSSN_CONFIG_FILE run pipelines/colorssn/colorssn.nf -params-file $OUTPUT_DIR/params.yml
