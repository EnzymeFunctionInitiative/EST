#!/bin/bash

if [[ "$1" == "mysql" ]]; then
    DATA_DIR="tests/test_data/mysql"
    export EFI_DB_NAME="efi_db"
    export EFI_TEST_ENV="mysql"
else
    DATA_DIR="tests/test_data/smalldata"
    export EFI_DB_NAME="$DATA_DIR/efi_db.sqlite"
    export EFI_TEST_ENV="sqlite"
fi

export EFI_TEST_DATA_DIR=$DATA_DIR
export EFI_CONFIG_FILE="$DATA_DIR/efi.config"
export EFI_FASTA_DB="$DATA_DIR/blastdb/combined.fasta"
export EFI_TEST_ACC_FILE="$DATA_DIR/accession_test.txt"
export EFI_TEST_FASTA_FILE="$DATA_DIR/fasta_test.fasta"
export EFI_TEST_BLAST_SEQ="$DATA_DIR/blast_query.fa"
export EFI_TEST_FAMILY_ID="$DATA_DIR/family_id.txt"
export EFI_TEST_SSN_UNIPROT="$DATA_DIR/ssn.xgmml"
export EFI_TEST_SSN_UNIREF90="$DATA_DIR/ssn_uniref90.xgmml"
export EFI_TEST_SSN_UNIREF50="$DATA_DIR/ssn_uniref50.xgmml"
export EFI_TEST_SSN_REPNODE="$DATA_DIR/ssn_repnode70.xgmml"

