#!/bin/bash

set -e

if [[ ! -e ssn.nf || ! -e est.nf ]]; then
    echo "Run this script from the repository root"
    exit 1
fi

source efi-env/bin/activate

if [ -d test_results ]; then 
    rm -rf test_results
fi 

# create EST params and execute pipeline
python create_est_nextflow_params.py family --output-dir test_results --efi-config smalldata/efi.config --fasta-db smalldata/databases/blastdb/combined.fasta --efi-db smalldata/databases/efi_db.sqlite --families PF07476 --family-id-format UniProt
nextflow -C conf/docker.config run est.nf -params-file test_results/params.yml

# create SSN params and exeute pipeline
python create_ssn_nextflow_params.py auto --filter-min-val 87 --ssn-name testssn --ssn-title test-ssn --est-output-dir test_results
# python create_ssn_nextflow_params.py manual --filter-min-val 87 --ssn-name name --ssn-title title --blast-parquet smalldata/results/1.out.parquet --fasta-file smalldata/results/all_sequences.fasta --output-dir test_results/ssn --efi-config smalldata/efi.config --efi-db smalldata/databases/efi_db.sqlite
nextflow -C conf/docker.config run ssn.nf -params-file test_results/ssn/params.yml