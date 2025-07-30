
process compute_stats {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path blast_parquet
        path fasta_file
        path import_stats
    output:
        path "boxplot_stats.parquet", emit: boxplot_stats
        path "evalue.tab", emit: evaluetab
        path "stats.json", emit: final_stats
    """
    # compute convergence ratio
    python $projectDir/statistics/conv_ratio.py --blast-output $blast_parquet --fasta $fasta_file --output conv_ratio.json

    python $projectDir/statistics/merge_stats.py --import-stats $import_stats --conv-ratio-stats conv_ratio.json --output stats.json

    # compute boxplot stats and evalue.tab
    python $projectDir/statistics/render_boxplotstats_sql_template.py --blast-output $blast_parquet --duckdb-temp-dir /scratch/duckdb-${params.job_id} --boxplot-stats-output boxplot_stats.parquet --evalue-output evalue.tab --sql-template $projectDir/templates/boxplotstats-template.sql --sql-output-file boxplotstats.sql
    duckdb < boxplotstats.sql
    """
}


process visualize {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path boxplot_stats
    output:
        path '*.png'
    """
    python $projectDir/visualization/plot_blast_results.py --boxplot-stats $boxplot_stats --job-id ${params.job_id} --length-plot-filename length --pident-plot-filename pident --edge-hist-filename edge --proxies sm:48
    """
}

workflow REPORTING {
    take:
        blast_parquet
        fasta_lengths_parquet
        fasta_file
        accession_table
        import_stats

    main:

        stats = compute_stats(blast_parquet, fasta_lengths_parquet, import_stats)

        plots = visualize(stats.boxplot_stats)

    emit:
        evalue_tab = stats.evaluetab
        final_stats = stats.final_stats
        plots = plots.collect()
}

