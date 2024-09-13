process unzip_input {
    input:
        path ssn_zipped
    output:
        path "ssn.xgmml"
    """
    perl $projectDir/../shared/unzip_input/unzip_file.pl -in $ssn_zipped -out ssn.xgmml
    """
}

