
def getCleanFilename(job_name, default_name) {
    // Create a clean job name for the file
    def clean_file_name = job_name
        .replaceAll(/[^\p{ASCII}]/, "")
        .replaceAll(/[^a-zA-Z0-9_\-\.]/, "_")
        .replaceAll(/^[_-]+|[_-]+$/, "");
    def file_name = (clean_file_name ?: default_name) + ".xgmml"
    return file_name
}


def prepareSsnFilename(default_name) {
    def final_job_name = prepareJobName(default_name)
    def file_name = getCleanFilename(final_job_name, default_name)
    return file_name
}


def prepareJobName(default_name) {
    def job_name = params.job_name ? params.job_name + " " + default_name : default_name
    def final_job_name = params.job_id ? params.job_id + "_" + job_name : job_name
    return final_job_name
}


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
        path "${file_to_zip}.zip"

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

