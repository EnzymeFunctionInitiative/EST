process import_sequences {
    input:
        val existing_fasta_file
    output:
        path "sequences.fa"
    """
    cp $existing_fasta_file sequences.fa
    """
}

process create_blast_db {
    input:
        path fasta_file
    output:
        path "database.*"
        val "database"
    """
    formatdb -i ${fasta_file} -n database -p T -o T
    """
}

process split_fasta {
    input:
        path fasta_file
    output:
        path "fracfile-*.fa"
    """
    ${params.est_dir}/split_fasta.pl -parts ${params.num_fasta_shards} -source ${fasta_file}
    """
}

process all_by_all_blast {
    input:
        path(blast_db_files, arity: 5)
        val blast_db_name
        each path(frac)
    output:
        path "${frac}.tab.parquet"
    """
    # module load efidb/ip98
    # module load efiest/devlocal
    # module load Python
    # module load efiest/python_est_1.0
    blastall -p blastp -i $frac -d $blast_db_name -m 8 -e 1e-5 -b ${params.num_blast_matches} -o ${frac}.tab
    python ${params.est_dir}/blastreduce/transcode_blast.py --blast-output ${frac}.tab
    """
}

process blastreduce_transcode_fasta {
    input:
        path fasta_file
    output:
        path "${fasta_file.getName()}.parquet"

    """
    # module load Python
    # module load efiest/python_est_1.0
    python ${params.est_dir}/blastreduce/transcode_fasta_lengths.py --fasta $fasta_file --output ${fasta_file.getName()}.parquet
    """
}

process blastreduce {
    publishDir "$baseDir/nextflow_results/", mode: 'copy'
    input:
        path blast_files
        path fasta_length_parquet

    output:
        path "1.out.parquet"

    """
    # module load Python
    # module load efiest/python_est_1.0
    # module load efidb/ip98
    python ${params.est_dir}/blastreduce/render_sql_template.py --blast-output $blast_files  --sql-template ${params.est_dir}/templates/reduce-template.sql --fasta-length-parquet $fasta_length_parquet --duckdb-memory-limit ${params.duckdb_memory_limit} --sql-output-file reduce.sql
    # module load DuckDB
    duckdb < reduce.sql
    """
}

process visualize_blast {
    input:
        path blast_parquet
    output:
        path 'length.png'
        path 'pident.png'
        path 'edge.png'
        path 'evalue.tab'

    """
    # module load Python
    # module load efiest/python_est_1.0
    python ${params.est_dir}/visualization/process_blast_results.py --blast-output $blast_parquet --job-id $job_id --length-plot-filename length --pident-plot-filename pident --edge-hist-filename edge --evalue-tab-filename evalue.tab --proxies sm:48
    """
}

process finalize_ouptut {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path blast_output
        path length_boxplot
        path pident_boxplot
        path edge_histo
        path evalue_tab
    output:
        path 'output.tar'
    """
    python finalize/transcode_blast_parquet.py --blast-parquet $blast_output
    # tar -cf output.tar 1.out $length_boxplot $pident_boxplot $edge_histo $evalue_tab
    """
}

workflow {
    // step 1: import sequences (stub that just copies the file)
    fasta_file = import_sequences(params.fasta_file)

    // step 2: create blastdb and frac seq file 
    fasta_lengths_parquet = blastreduce_transcode_fasta(fasta_file)
    fasta_fractions = split_fasta(fasta_file)
    blastdb = create_blast_db(fasta_file)

    // step 3: all-by-all blast and blast reduce
    blast_fractions = all_by_all_blast(blastdb, fasta_fractions) | collect
    reduced_blast_parquet = blastreduce(blast_fractions, fasta_lengths_parquet)

    // step 4: visualize and save
    plots = visualize_blast(reduced_blast_parquet)

    // step 5: copy files to output dir
    finalize_ouptut(reduced_blast_parquet, plots)
}