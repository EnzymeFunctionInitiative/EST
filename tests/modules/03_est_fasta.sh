#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2
NXF_EST_CONFIG_FILE="conf/est/$CONFIG_FILE"
NXF_SSN_CONFIG_FILE="conf/generatessn/$CONFIG_FILE"

OUTPUT_DIR="$TEST_RESULTS_DIR/test_results_fasta"

rm -rf $OUTPUT_DIR

./bin/create_est_nextflow_params.py fasta --output-dir $OUTPUT_DIR --efi-config smalldata/efi.config --fasta-db smalldata/blastdb/combined.fasta --efi-db smalldata/efi_db.sqlite --fasta-file smalldata/test.fasta
nextflow -C $NXF_EST_CONFIG_FILE run pipelines/est/est.nf -params-file $OUTPUT_DIR/params.yml

./bin/create_generatessn_nextflow_params.py auto --filter-min-val 87 --ssn-name testssn --ssn-title test-ssn --est-output-dir $OUTPUT_DIR
# ./bin/create_ssn_nextflow_params.py manual --filter-min-val 87 --ssn-name name --ssn-title title --blast-parquet smalldata/results/1.out.parquet --fasta-file smalldata/results/all_sequences.fasta --output-dir $OUTPUT_DIR/ssn --efi-config smalldata/efi.config --efi-db smalldata/efi_db.sqlite
nextflow -C $NXF_SSN_CONFIG_FILE run pipelines/generatessn/generatessn.nf -params-file $OUTPUT_DIR/ssn/params.yml