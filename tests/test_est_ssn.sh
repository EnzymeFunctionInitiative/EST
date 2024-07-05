#!/bin/bash

set -e

if [[ ! -e ssn.nf || ! -e est.nf ]]; then
    echo "Run this script from the repository root"
    exit 1
fi

source efi-env/bin/activate

rm -rf test_results_*

## Test Family import
# create EST params and execute pipeline
python create_est_nextflow_params.py family --output-dir test_results_family --efi-config smalldata/efi.config --fasta-db smalldata/databases/blastdb/combined.fasta --efi-db smalldata/databases/efi_db.sqlite --families PF07476 --family-id-format UniProt
nextflow -C conf/docker.config run est.nf -params-file test_results_family/params.yml
# create SSN params and exeute pipeline
python create_ssn_nextflow_params.py auto --filter-min-val 87 --ssn-name testssn --ssn-title test-ssn --est-output-dir test_results_family
# python create_ssn_nextflow_params.py manual --filter-min-val 87 --ssn-name name --ssn-title title --blast-parquet smalldata/results/1.out.parquet --fasta-file smalldata/results/all_sequences.fasta --output-dir test_results_family/ssn --efi-config smalldata/efi.config --efi-db smalldata/databases/efi_db.sqlite
nextflow -C conf/docker.config run ssn.nf -params-file test_results_family/ssn/params.yml


## Test FASTA import
# create EST params and execute pipeline
python create_est_nextflow_params.py fasta --output-dir test_results_fasta --efi-config smalldata/efi.config --fasta-db smalldata/databases/blastdb/combined.fasta --efi-db smalldata/databases/efi_db.sqlite --fasta-file smalldata/test.fasta
nextflow -C conf/docker.config run est.nf -params-file test_results_fasta/params.yml
# create SSN params and exeute pipeline
python create_ssn_nextflow_params.py auto --filter-min-val 87 --ssn-name testssn --ssn-title test-ssn --est-output-dir test_results_fasta
# python create_ssn_nextflow_params.py manual --filter-min-val 87 --ssn-name name --ssn-title title --blast-parquet smalldata/results/1.out.parquet --fasta-file smalldata/results/all_sequences.fasta --output-dir test_results_fasta/ssn --efi-config smalldata/efi.config --efi-db smalldata/databases/efi_db.sqlite
nextflow -C conf/docker.config run ssn.nf -params-file test_results_fasta/ssn/params.yml
