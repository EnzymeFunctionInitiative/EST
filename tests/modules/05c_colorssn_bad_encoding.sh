#!/bin/bash
set -e

if [[ ! -e "$EFI_TEST_SSN_UNIPROT" ]]; then
    echo "Test skipped; missing $EFI_TEST_SSN_UNIPROT"
    exit 0
fi

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2

self=$(basename "$0" .sh)
OUTPUT_DIR="$TEST_RESULTS_DIR/$self"

rm -rf $OUTPUT_DIR

mkdir $OUTPUT_DIR

BAD_ENCODING_FILE="$OUTPUT_DIR/bad_encoding.xgmml"
SANITIZED_COMP_FILE="$OUTPUT_DIR/sanitized_comp.xgmml"
SANITIZED_FILE="$OUTPUT_DIR/sanitized_out.xgmml"
UTF8_ENCODING_FILE="$OUTPUT_DIR/utf8_encoding.xgmml"
UNCHANGED_UTF8_FILE="$OUTPUT_DIR/utf8_encoding_unchanged.xgmml"

printf '<?xml version="1.0" encoding="UTF-8"?>\n<title>EEVS+DDGS \xc0\xc7\xbd\xc9 cluster</title>\n' > $BAD_ENCODING_FILE
printf '<?xml version="1.0" encoding="UTF-8"?>\n<title>EEVS+DDGS      cluster</title>\n' > $SANITIZED_COMP_FILE
printf '<?xml version="1.0" encoding="UTF-8"?>\n<title>EEVS+DDGS cluster</title>\n' > $UTF8_ENCODING_FILE
printf '<?xml version="1.0" encoding="UTF-8"?>\n<title>EEVS+DDGS cluster</title>\n' > $UNCHANGED_UTF8_FILE

python pipelines/shared/python/sanitize_xgmml.py --input $BAD_ENCODING_FILE --output $SANITIZED_FILE

if ! diff -q $SANITIZED_FILE $SANITIZED_COMP_FILE > /dev/null; then
    echo "Test failed: encoding was not sanitized; $SANITIZED_FILE did not match $SANITIZED_COMP_FILE"
    exit 1
fi

python pipelines/shared/python/sanitize_xgmml.py --input $UTF8_ENCODING_FILE --output $UNCHANGED_UTF8_FILE

if ! diff -q $UTF8_ENCODING_FILE $UNCHANGED_UTF8_FILE > /dev/null; then
    echo "Test failed: sanitizing script modified UTF-8 file"
    exit 1
fi

