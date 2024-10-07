#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2
NXF_EST_CONFIG_FILE="conf/est/$CONFIG_FILE"
NXF_SSN_CONFIG_FILE="conf/generatessn/$CONFIG_FILE"

OUTPUT_DIR="$TEST_RESULTS_DIR/test_results_accession"

rm -rf $OUTPUT_DIR

./bin/create_est_nextflow_params.py accessions --output-dir $OUTPUT_DIR --efi-config $EFI_CONFIG_FILE --fasta-db $EFI_FASTA_DB --efi-db $EFI_DB_NAME --accessions-file $EFI_TEST_ACC_FILE
nextflow -C $NXF_EST_CONFIG_FILE run pipelines/est/est.nf -params-file $OUTPUT_DIR/params.yml

./bin/create_generatessn_nextflow_params.py auto --filter-min-val 87 --ssn-name testssn --ssn-title test-ssn --est-output-dir $OUTPUT_DIR
# ./bin/create_ssn_nextflow_params.py manual --filter-min-val 87 --ssn-name name --ssn-title title --blast-parquet smalldata/results/1.out.parquet --fasta-file smalldata/results/all_sequences.fasta --output-dir $OUTPUT_DIR/ssn --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME
nextflow -C $NXF_SSN_CONFIG_FILE run pipelines/generatessn/generatessn.nf -params-file $OUTPUT_DIR/ssn/params.yml

