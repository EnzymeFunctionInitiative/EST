
process unzip_ssn {
    input:
        path ssn_zipped

    output:
        path "ssn____local.xgmml"

    script:
    """
    perl $projectDir/../shared/perl/unzip_xgmml_file.pl --in $ssn_zipped --out ssn____local.xgmml
    """
}


process zip_files {
    publishDir params.final_output_dir, mode: "copy"

    input:
        path file_to_zip

    output:
        path "*.zip"

    script:
    """
    zip "${file_to_zip}.zip" "${file_to_zip}"
    """
}


process merge_stats {
    publishDir params.final_output_dir, mode: "copy"

    input:
        path stats_files

    output:
        path "stats.json"

    script:
    """
    python $projectDir/../shared/python/merge_stats.py --input ${stats_files} --output stats.json
    """
}

