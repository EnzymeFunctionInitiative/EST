#!/bin/bash
set -e # Exit immediately if any command fails

# Source the common setup script
# (Assumes common.sh is in the same directory as this script)
source "$(dirname "$0")/common.sh"

DATA_URL="https://efi.igb.illinois.edu/downloads/sample_data/est_nextflow_tests/expand_collapse.tar.gz"
ARCHIVE_NAME="expand_collapse.tar.gz"
EXPECTED_DIR="expand_collapse" # The folder inside the tar.gz

# Ensure data is present
ensure_test_data "$DATA_URL" "$ARCHIVE_NAME" "$EXPECTED_DIR"

# Set paths relative to the TEST_DATA_DIR variable (provided by common.sh)
BLAST_INPUT="${TEST_DATA_DIR}/${EXPECTED_DIR}/blast_demux.mux.out"
CLUSTER_FILE="${TEST_DATA_DIR}/${EXPECTED_DIR}/sequences.fasta.clstr"

echo "Starting Verification Workflow..."
echo "   Input: $BLAST_INPUT"
echo "   Clusters: $CLUSTER_FILE"

# Note: using $SCRIPT_DIR (from common.sh) to find the .nf file relative to this script
nextflow run "${SCRIPT_DIR}/verify_cluster_expand.nf" \
    --blast_input "$BLAST_INPUT" \
    --cdhit_input "$CLUSTER_FILE"

echo "Verification finished successfully"

