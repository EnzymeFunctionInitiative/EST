
def memoryBudget(mem, frac = 0.8, min_headroom_mb = 1024, min_budget_mb = 256) {
    // Compute a memory limit to hand to a tool (DuckDB, CD-HIT, ...) that sits below the
    // task's allocation. A tool's own limit rarely covers everything the process uses
    // (interpreter, allocator, per-thread state), so without headroom the scheduler can
    // OOM-kill the job. Returns the smaller of frac * mem and mem - min_headroom_mb, but
    // never less than min_budget_mb. Callers format the result for their tool, e.g.
    //   DuckDB: "${memoryBudget(task.memory).toMega()}MiB"
    //   CD-HIT: -M ${memoryBudget(task.memory, 0.9).toMega()}
    if (!(mem instanceof nextflow.util.MemoryUnit)) {
        throw new IllegalArgumentException(
            "memoryBudget: expected a MemoryUnit (e.g. task.memory) but got " +
            "${mem == null ? 'null' : mem.getClass().name}; set a memory allocation for this process"
        )
    }
    def total_mb = mem.toMega()
    def budget_mb = Math.min((long)(total_mb * frac), total_mb - min_headroom_mb)
    return new nextflow.util.MemoryUnit(Math.max(budget_mb, (long)min_budget_mb) * 1024L * 1024L)
}


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
        path stats_files, stageAs: 'inputs/*'

    output:
        path "stats.json"

    script:
    """
    python $projectDir/../shared/python/merge_stats.py --input inputs/* --output stats.json
    """
}

