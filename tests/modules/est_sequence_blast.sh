#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
NXF_EST_CONFIG_FILE=$2
NXF_SSN_CONFIG_FILE=$3

OUTPUT_DIR="$TEST_RESULTS_DIR/test_results_sequence_blast"

rm -rf $OUTPUT_DIR

python create_est_nextflow_params.py blast --output-dir $OUTPUT_DIR --efi-config smalldata/efi.config --fasta-db smalldata/blastdb/combined.fasta --efi-db smalldata/efi_db.sqlite --blast-query-file smalldata/blast_query.fa
nextflow -C $NXF_EST_CONFIG_FILE run est.nf -params-file $OUTPUT_DIR/params.yml

python create_ssn_nextflow_params.py auto --filter-min-val 87 --ssn-name testssn --ssn-title test-ssn --est-output-dir $OUTPUT_DIR
# python create_ssn_nextflow_params.py manual --filter-min-val 87 --ssn-name name --ssn-title title --blast-parquet smalldata/results/1.out.parquet --fasta-file smalldata/results/all_sequences.fasta --output-dir $OUTPUT_DIR/ssn --efi-config smalldata/efi.config --efi-db smalldata/efi_db.sqlite
nextflow -C $NXF_SSN_CONFIG_FILE run ssn.nf -params-file $OUTPUT_DIR/ssn/params.yml