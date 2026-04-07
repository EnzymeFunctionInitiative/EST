
TEMP_FILE_NAME = "a file name with spaces.txt"

process verify_staging {
    debug true

    input:
    path staged_file

    script:
    """
    echo "--- Debugging inside the Shell ---"
    echo "The value of the variable is: '$staged_file'"
    
    echo "We use the variable WITHOUT quotes to prove it's a safe, single string."
    echo "If it had spaces and wasn't quoted, 'ls' or 'cat' would fail."
    ls -l $staged_file
    
    echo "Content of file:"
    cat $staged_file
    """
}

workflow {
    // Create a dummy file with spaces in the name
    def tempFile = file(TEMP_FILE_NAME)
    tempFile.text = "Nextflow staging handled file with spaces."
    println "Creating temp file '${tempFile.name}' in current directory"

    // Pass it to the process
    verify_staging(tempFile)
}

workflow.onComplete {
    def tempFile = file(TEMP_FILE_NAME)
    if( tempFile.exists() ) {
        println "Cleaning up temporary file: ${tempFile.name}"
        tempFile.delete()
    }
}
