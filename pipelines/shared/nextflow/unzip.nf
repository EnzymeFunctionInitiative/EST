
process unzip_ssn {
    input:
        path ssn_zipped
    output:
        path "ssn____local.xgmml"
    """
    perl $projectDir/../shared/perl/unzip_xgmml_file.pl --in $ssn_zipped --out ssn____local.xgmml
    """
}

process zip_file {
    //publishDir params.final_output_dir, mode: "copy"
    input:
        path file
    output:
        path "${file}.zip"
    """
    zip -j ${file}.zip ${file}
    """
}

