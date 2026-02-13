
include { get_length_histogram } from "../../shared/nextflow/sequence.nf"
include { merge_stats } from "../../shared/nextflow/util.nf"

process compute_stats {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path blast_parquet
        path fasta_file
    output:
        path "boxplot_stats.parquet", emit: boxplot_stats
        path "evalue.tab", emit: evaluetab
        path "conv_ratio.json", emit: stats
    """
    # compute convergence ratio
    python $projectDir/statistics/conv_ratio.py --blast-output $blast_parquet --fasta $fasta_file --output conv_ratio.json

    # compute boxplot stats and evalue.tab
    python $projectDir/statistics/render_boxplotstats_sql_template.py --blast-output $blast_parquet --duckdb-memory-limit ${params.duckdb_memory_limit} --duckdb-temp-dir ${params.duckdb_temp_dir}-${task.hash} --boxplot-stats-output boxplot_stats.parquet --evalue-output evalue.tab --sql-template $projectDir/templates/boxplotstats-template.sql --sql-output-file boxplotstats.sql
    duckdb < boxplotstats.sql
    """
}

process visualize_boxplot_stats {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path boxplot_stats
    output:
        path '*.json', emit: json
        path '*.png', emit: plots
    """
    python $projectDir/visualization/plot_blast_results.py --boxplot-stats $boxplot_stats --job-id ${params.job_id} --length-plot-filename alignment_length --pident-plot-filename percent_identity --edge-hist-filename number_of_edges --proxies sm:48
    python $projectDir/visualization/export_blast_results_plot_json.py --boxplot-stats $boxplot_stats --length-json-filename alignment_length.json --pident-json-filename percent_identity.json --edge-hist-json-filename number_of_edges.json
    """
}

process visualize_length_histograms {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path length_histogram_file
    output:
        path '*.json', emit: json
        path '*.png', emit: plots
    """
    base_name=\$(basename "${length_histogram_file}" .histogram.txt)
    python $projectDir/visualization/plot_length_data.py --lengths $length_histogram_file --job-id ${params.job_id} --frac 1 --plot-filename length_histogram_\${base_name} --output-type png --proxies sm:48
    python $projectDir/visualization/export_length_histogram_json.py --lengths $length_histogram_file --frac 1 --output-json-filename length_histogram_\${base_name}.json 
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
        seq_versions = ['uniprot']
        if (params.sequence_version == "uniref50") {
            seq_versions = ["uniprot", "uniref90", "uniref50"]
        } else if (params.sequence_version == "uniref90") {
            seq_versions = ["uniprot", "uniref90"]
        }
        seq_version_ch = Channel.fromList(seq_versions)
        length_histograms = get_length_histogram(fasta_file, accession_table, seq_version_ch)

        stats = compute_stats(blast_parquet, fasta_lengths_parquet)

        boxplot_viz = visualize_boxplot_stats(stats.boxplot_stats)
        histo_viz = visualize_length_histograms(length_histograms)

        files_to_merge_stream = import_stats.mix(stats.stats)
        files_to_merge_stream.collect().set { files_to_merge }
        final_stats = merge_stats(files_to_merge)

    emit:
        evalue_tab = stats.evaluetab
        final_stats
        boxplot_json = boxplot_viz.json.collect()
        boxplot_plots = boxplot_viz.plots.collect()
        histo_json = histo_viz.json.collect()
        histo_plots = histo_viz.plots.collect()
}

