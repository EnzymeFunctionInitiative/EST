process import_data {
    containerOptions "-v ${params.blast_parquet}:${params.blast_parquet} -v ${params.fasta_file}:${params.fasta_file} -v ${params.seq_meta_file}:${params.seq_meta_file}"
    input:
        val existing_blast_output
        val existing_fasta_file
        val existing_seq_meta_file
    output:
        path '1.out.parquet', emit: blast_output
        path 'sequences.fa', emit: fasta
        path 'sequence_metadata.tab', emit: seq_meta_file
    """
    cp $existing_blast_output 1.out.parquet
    cp $existing_fasta_file sequences.fa
    cp $existing_seq_meta_file sequence_metadata.tab
    """
}

process filter_blast {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path blast_parquet
    output:
        path "2.out"
    """
    python $projectDir/filter/render_filter_blast_sql_template.py --blast-output $blast_parquet --filter-parameter ${params.filter_parameter} --filter-min-val ${params.filter_min_val} --min-length ${params.min_length} --max-length ${params.max_length} --sql-template $projectDir/templates/filterblast-template.sql --output-file 2.out --sql-output-file filterblast.sql
    duckdb < filterblast.sql
    """
}

process filter_fasta {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path fasta
        path seq_meta_file
    output:
        path "filtered_sequences.fasta", emit: filtered_fasta
        path "filtered_sequence_metadata.tab", emit: filtered_seq_meta_file
    """
    perl $projectDir/filter/filter_fasta.pl --fastain $fasta --fastaout filtered_sequences.fasta -minlen ${params.min_length} --maxlen ${params.max_length}
    cp $seq_meta_file filtered_sequence_metadata.tab
    """
}

process get_annotations {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path filtered_seq_meta_file
    output:
        path "ssn_metadata.tab"
    script:
    """
    perl $projectDir/annotations/get_annotations.pl --ssn-anno-out ssn_metadata.tab --uniref-version ${params.uniref_version} --min-len ${params.min_length} --max-len ${params.max_length} --seq-meta-in $filtered_seq_meta_file --config ${params.efi_config} --db-name ${params.efi_db}
    """
}

process create_full_ssn {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path filtered_blast
        path filtered_fasta
        path ssn_meta_file
    output:
        path "full_ssn.xgmml"
    """
    perl $projectDir/create/create_full_ssn.pl --blast $filtered_blast --fasta $filtered_fasta --metadata $ssn_meta_file --output full_ssn.xgmml  --title ${params.ssn_title} --dbver ${params.db_version}
    """
}

process compute_stats {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path full_ssn
    output:
        path "stats.tab"
    """
    perl $projectDir/stats/stats.pl -run-dir . -out stats.tab
    """
}

workflow {
    // import data from EST run
    input_data = import_data(params.blast_parquet, params.fasta_file, params.seq_meta_file)

    // filter BLAST and fasta file
    filtered_blast = filter_blast(input_data.blast_output)
    fasta_filter_outputs = filter_fasta(input_data.fasta, input_data.seq_meta_file)

    // get annotations
    ssn_meta_file = get_annotations(fasta_filter_outputs.filtered_seq_meta_file)

    // create networks
    full_ssn = create_full_ssn(filtered_blast, fasta_filter_outputs.filtered_fasta, ssn_meta_file)

    // compute stats
    stats = compute_stats(full_ssn)
}
