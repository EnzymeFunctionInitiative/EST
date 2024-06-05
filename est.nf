process import_sequences {
    input:
        val existing_fasta_file
    output:
        path "sequences.fa"
    """
    cp $existing_fasta_file sequences.fa
    """
}

process multiplex {
    input:
        path fasta_file
    output:
        "sequences.fa"
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
    $projectDir/split_fasta.pl -parts ${params.num_fasta_shards} -source ${fasta_file}
    """
}

process all_by_all_blast {
    input:
        path(blast_db_files, arity: 5)
        val blast_db_name
        each path(frac)
    output:
        path "${frac}.tab.sorted.parquet"
    """
    # run blast to get similarity metrics
    blastall -p blastp -i $frac -d $blast_db_name -m 8 -e 1e-5 -b ${params.num_blast_matches} -o ${frac}.tab

    # transcode to parquet for speed, creates frac.tab.parquet
    python $projectDir/blastreduce/transcode_blast.py --blast-output ${frac}.tab

    # in each row, ensure that qseqid < sseqid lexicographically
    python $projectDir/blastreduce/render_prereduce_sql_template.py --blast-output ${frac}.tab.parquet --sql-template $projectDir/templates/prereduce-template.sql --output-file ${frac}.tab.sorted.parquet --duckdb-temp-dir /scratch/duckdb-${params.job_id} --sql-output-file prereduce.sql
    duckdb < prereduce.sql
    """
}

process blastreduce_transcode_fasta {
    input:
        path fasta_file
    output:
        path "${fasta_file.getName()}.parquet"

    """
    python $projectDir/blastreduce/transcode_fasta_lengths.py --fasta $fasta_file --output ${fasta_file.getName()}.parquet
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
    python $projectDir/blastreduce/render_reduce_sql_template.py --blast-output $blast_files  --sql-template $projectDir/templates/reduce-template.sql --fasta-length-parquet $fasta_length_parquet --duckdb-memory-limit ${params.duckdb_memory_limit} --duckdb-temp-dir /scratch/duckdb-${params.job_id} --sql-output-file allreduce.sql
    
    duckdb < allreduce.sql
    """
}

process compute_stats {
    input:
        path blast_parquet
        path fasta_file
    output:
        path "boxplot_stats.parquet", emit: boxplot_stats
        path "evalue.tab", emit: evaluetab
        path "acc_counts.json", emit: acc_counts
    """
    # compute convergence ratio
    python $projectDir/statistics/conv_ratio.py --blast-output $blast_parquet --fasta $fasta_file --output acc_counts.json

    # compute boxplot stats and evalue.tab
    python $projectDir/statistics/render_boxplotstats_sql_template.py --blast-output $blast_parquet --duckdb-temp-dir /scratch/duckdb-${params.job_id} --boxplot-stats-output boxplot_stats.parquet --evalue-output evalue.tab --sql-template $projectDir/templates/boxplotstats-template.sql --sql-output-file boxplotstats.sql
    duckdb < boxplotstats.sql
    """
}

process visualize {
    input:
        path boxplot_stats
    output:
        path 'length.png'
        path 'pident.png'
        path 'edge.png'

    """
    python $projectDir/visualization/plot_blast_results.py --boxplot-stats $boxplot_stats --job-id ${params.job_id} --length-plot-filename length --pident-plot-filename pident --edge-hist-filename edge --proxies sm:48
    """
}

process finalize_output {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path blast_output
        path length_boxplot
        path pident_boxplot
        path edge_histo
        path evalue_tab
        path acc_counts
    output:
        path blast_output
        path length_boxplot
        path pident_boxplot
        path edge_histo
        path evalue_tab
        path acc_counts
    """
    echo 'Finalizing'
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

    // step 4: compute convergence ratio and boxplot stats
    stats = compute_stats(reduced_blast_parquet, fasta_lengths_parquet)

    // step 5: visualize
    plots = visualize(stats.boxplot_stats)

    // step 5: copy files to output dir
    finalize_output(reduced_blast_parquet, plots, stats.evaluetab, stats.acc_counts)
}