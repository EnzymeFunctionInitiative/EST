#!/bin/bash
set -e

TEST_RESULTS_DIR=$1
CONFIG_FILE=$2

self=$(basename "$0" .sh)
OUTPUT_DIR="$TEST_RESULTS_DIR/$self"

rm -rf $OUTPUT_DIR
mkdir $OUTPUT_DIR

fasta_file="$TEST_RESULTS_DIR/test_input.fasta"
cp $EFI_TEST_FASTA_FILE $fasta_file
cat << 'EOS' >> $fasta_file
>TEST1_ID
MKVKKVLCSEALTGFYMDDKEAIKSGAKSDGFVYKGAPVTPGFKSIRQPGVAVSVMFVLEDGHVVYGDCAVAQYAASGGR
EVPNTAAALIKVIEKYVTPYFEGMDIKEFKSTAEKFDRYEFDGERLPASIRYGVTQAILEAAAYEQKLTMCEVILNEYNL
PVDLTPVRINAQSGDERYTNVDKMILKKVGMMPHGLINNVEEKLGKDGQIFLDWVKWVTKRISDIGEPDYKPVMRYDVYG
CMGKAFDNDLDKVGEYLIKVADACAPYEVFVEMPVDMKSNEKQLEAMKYLRKYLDDAGCRLKLIIDEYANTYEEIVEWVD
AKGADMVQVKTIDLGGINNIVEADLYCKAHGVLAYQGGTCNQTDKAAIVCANLAVATKPFAMAGTPGMGVDEGVMIVSNE
QERLLAILKAKQEGKI
>TEST2_ID:HCJ58040.1 MAG TPA: methylaspartate ammonia-lyase, partial [Clostridiaceae bacterium]
PYFEGKNIKEFKKTAEEFDRKLFDGVRLPAPIRYGVTQAILETVAKEQHITMTEVIANEYGIELELKPVR
INAQSGDERYTNVDKMILKEVGMMPHGLINNVEDKLGKDGKKFLDWVKWVKNRIQDIGDPNYKPVMRYDV
YGCMGKAFNNDLDKVVEYLIEVEXEEQLKGMKYLRKKLDEAGSKLKLIIDEYANTYEEIVQWVDAKGADM
VQVKTIDLGGINNIVEAVLYCKKNGVLAYQGGTCNETDKSALVCVNLAVATQPFAMAGKPGMGVDEGVMI
VNNEQQRLLAILKAKKEGLI
EOS

./bin/create_est_nextflow_params.py fasta --output-dir $OUTPUT_DIR --efi-config $EFI_CONFIG_FILE --fasta-db $EFI_FASTA_DB --efi-db $EFI_DB_NAME --input-file $fasta_file --nextflow-config $CONFIG_FILE
bash $OUTPUT_DIR/run_nextflow.sh

./bin/create_generatessn_nextflow_params.py auto --threshold-min-val 87 --ssn-name testssn --job-name test-ssn --est-output-dir $OUTPUT_DIR --nextflow-config $CONFIG_FILE --efi-config $EFI_CONFIG_FILE --efi-db $EFI_DB_NAME
bash $OUTPUT_DIR/ssn/run_nextflow.sh

ssn_file=$(mktemp)
exit_code=0
unzip -c $OUTPUT_DIR/ssn/full_ssn.xgmml.zip > "$ssn_file"
if ! grep -q ZZZZZ "$ssn_file"; then
    printf "\033[0;31mFAILED test; no unknown sequences detected\033[0m\n"
    exit_code=1
elif ! grep -q TEST1_ID "$ssn_file"; then
    printf "\033[0;31mFAILED test; raw ID not present\033[0m\n"
    exit_code=1
elif ! grep -q HCJ58040 "$ssn_file"; then
    printf "\033[0;31mFAILED test; metadata not present\033[0m\n"
    exit_code=1
else
    printf "\033[0;32mTest passed\033[0m\n"
    exit_code=0
fi

rm $fasta_file
rm "$ssn_file"
exit $exit_code

