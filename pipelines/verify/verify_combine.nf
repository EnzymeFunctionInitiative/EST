
FILE1 = 'temp_a/file1'
FILE2 = 'temp_a/file2'
FILE3 = 'temp_a/file3'
STATS = 'temp_a/stats'
PCT = [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50]

process verify_it {
    debug true

    input:
        path t1
        path t2
        path t3
        val pct

    output:
        path "ssn_${pct}.xgmml", emit: ssn
        path "stats_${pct}.json", emit: stats

    script:
    """
    touch ssn_${pct}.xgmml
    echo "${pct}" > stats_${pct}.json
    """
}

process do_zip {
    publishDir "temp_a", mode: "copy"

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
    publishDir "temp_a", mode: "copy"

    input:
        path stats_files

    output:
        path "merged.json"

    script:
    """
    cat ${stats_files} > merged.json
    """
}

process make_full {
    input:
        path t1
        path t2
        path t3
    output:
        path "ssn_full.xgmml", emit: ssn
        path "stats_full.json", emit: stats
    script:
    """
    touch ssn_full.xgmml
    echo "full" > stats_full.json
    """
}

workflow {
    // Create a dummy file with spaces in the name
    def temp1 = file(FILE1)
    def temp2 = file(FILE2)
    def temp3 = file(FILE3)
    temp1.text = "Test1"
    temp2.text = "Test2"
    temp3.text = "Test3"
    println "Creating temp files in current directory"

    def pct_ch = Channel.from(PCT)

    full = make_full(temp1, temp2, temp3)

    // Pass it to the process
    output = verify_it(temp1, temp2, temp3, pct_ch)
    do_zip(output.ssn)

    def all_stats = full.stats.mix(output.stats).collect()
    merge_stats(all_stats)
}

workflow.onComplete {
    def temp1 = file(FILE1)
    if( temp1.exists() ) {
        println "Cleaning up temporary file: ${temp1.name}"
        temp1.delete()
    }
    def temp2 = file(FILE2)
    if( temp2.exists() ) {
        println "Cleaning up temporary file: ${temp2.name}"
        temp2.delete()
    }
    def temp3 = file(FILE3)
    if( temp3.exists() ) {
        println "Cleaning up temporary file: ${temp3.name}"
        temp3.delete()
    }
    def stats = file(STATS)
    if( stats.exists() ) {
        println "Cleaning up temporary file: ${stats.name}"
        stats.delete()
    }
}
