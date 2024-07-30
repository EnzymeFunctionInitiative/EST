process import_data {
    containerOptions "-v ${params.blast_parquet}:${params.blast_parquet} -v ${params.fasta_file}:${params.fasta_file}"
    input:
        val existing_blast_output
        val existing_fasta_file
    output:
        path '1.out.parquet', emit: blast_output
        path 'sequences.fa', emit: fasta
    """
    cp $existing_blast_output 1.out.parquet
    cp $existing_fasta_file sequences.fa
    """
}

process filter_blast {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path blast_parquet
    output:
        path "2.out"
    """
    python $projectDir/src/filter/render_filter_blast_sql_template.py --blast-output $blast_parquet --filter-parameter ${params.filter_parameter} --filter-min-val ${params.filter_min_val} --min-length ${params.min_length} --max-length ${params.max_length} --sql-template $projectDir/templates/filterblast-template.sql --output-file 2.out --sql-output-file filterblast.sql
    duckdb < filterblast.sql
    """
}

process filter_fasta {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path fasta
    output:
        path "filtered_sequences.fasta", emit: filtered_fasta
        path "fasta.metadata", emit: fasta_metadata
    """
    perl $projectDir/src/filter/filter_fasta.pl --fastain $fasta --fastaout filtered_sequences.fasta -minlen ${params.min_length} -maxlen ${params.max_length} -domain-meta fasta.metadata
    """
}

process get_annotations {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path fasta_metadata
    output:
        path "struct.filtered.out"
    script:
    """
    perl $projectDir/src/annotations/get_annotations.pl -out struct.filtered.out -uniref-version ${params.uniref_version} -min-len ${params.min_length} -max-len ${params.max_length} -meta-file $fasta_metadata -config ${params.efi_config} --db-name ${params.efi_db}
    """
}

process create_xgmml_100 {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path filtered_blast
        path filtered_fasta
        path struct_file
    output:
        path "full_ssn.xgmml"
    """
    perl $projectDir/src/create/xgmml_100_create.pl -blast=$filtered_blast -fasta $filtered_fasta -struct $struct_file -output full_ssn.xgmml  -title ${params.ssn_title} -dbver ${params.db_version}
    """
}

process compute_stats {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path full_ssn
    output:
        path "stats.tab"
    """
    perl $projectDir/src/stats/stats.pl -run-dir . -out stats.tab
    """
}

workflow {
    // import data from EST run
    input_data = import_data(params.blast_parquet, params.fasta_file)

    // filter BLAST and fasta file
    filtered_blast = filter_blast(input_data.blast_output)
    fasta_filter_outputs = filter_fasta(input_data.fasta)

    // get annotations
    struct_file = get_annotations(fasta_filter_outputs.fasta_metadata)

    // create networks
    full_ssn = create_xgmml_100(filtered_blast, fasta_filter_outputs.filtered_fasta, struct_file)

    // compute stats
    stats = compute_stats(full_ssn)
}