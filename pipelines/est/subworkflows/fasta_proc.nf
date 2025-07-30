
process cat_fasta_files {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path '*.fasta'
    output:
        path 'all_sequences.fasta'
    script:
    cat_cmd = "cat *.fasta > all_sequences.fasta"
    if (params.import_mode == "blast") {
        """
        $cat_cmd
        perl $projectDir/import/append_blast_query.pl --blast-query-file ${params.blast_query_file} --output-sequence-file all_sequences.fasta
        """
    } else {
        cat_cmd
    }
}

// If importing FASTA file, reformat the FASTA file and create the file that will be added to
// the dataset for all-by-all BLAST.  Sequence metadata is used to ensure that any sequences
// that were filtered out in a prior step are also removed when rewriting the user fasta.
process import_fasta {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path sequence_metadata
        path sequence_mapping
    output:
        path "imported_sequences.fasta", emit: "fasta_file"
    """
    perl $projectDir/import/import_fasta.pl --uploaded-fasta ${params.uploaded_fasta_file} \
        --sequence-mapping-file ${sequence_mapping} --sequence-metadata-file ${sequence_metadata} \
        --output-sequence-file imported_sequences.fasta
    """
}

