
include { visualize_length_histograms } from "../../shared/nextflow/reporting.nf"
include { merge_stats } from "../../shared/nextflow/util.nf"

process compute_stats {
    label APP_duckdb

    publishDir params.final_output_dir, mode: 'copy'

    input:
        path blast_parquet
        path fasta_file
    output:
        path "boxplot_stats.parquet", emit: boxplot_stats
        path "evalue.tab", emit: evaluetab
        path "conv_ratio.json", emit: stats

    script:
    """
    # compute convergence ratio
    python $projectDir/../shared/statistics/conv_ratio.py \
        --blast-output $blast_parquet \
        --fasta $fasta_file \
        --output conv_ratio.json

    # compute boxplot stats and evalue.tab
    DUCKDB_TEMP="${params.duckdb_temp_dir}/duckdb-${task.index}-"\$(date +%s)
    python $projectDir/statistics/render_boxplotstats_sql_template.py \
        --blast-output $blast_parquet \
        --duckdb-memory-limit "${task.memory.toGiga()}GB" \
        --duckdb-n-threads ${task.cpus} \
        --duckdb-temp-dir \${DUCKDB_TEMP} \
        --boxplot-stats-output boxplot_stats.parquet \
        --evalue-output evalue.tab \
        --sql-template $projectDir/templates/boxplotstats-template.sql \
        --sql-output-file boxplotstats.sql
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

    script:
    """
    python $projectDir/visualization/plot_blast_results.py \
        --boxplot-stats $boxplot_stats \
        --job-id ${params.job_id} \
        --length-plot-filename alignment_length \
        --pident-plot-filename percent_identity \
        --edge-hist-filename number_of_edges \
        --proxies sm:48
    python $projectDir/visualization/export_blast_results_plot_json.py \
        --boxplot-stats $boxplot_stats \
        --length-json-filename alignment_length.json \
        --pident-json-filename percent_identity.json \
        --edge-hist-json-filename number_of_edges.json
    """
}

process get_length_histogram {
    input:
        path sequence_lengths
        path accession_table
        val seq_version
    output:
        tuple val(seq_version), path("${seq_version}.histogram.txt")

    script:
    """
    python $projectDir/../shared/visualization/compute_length_histogram.py \
        --length-mapping ${sequence_lengths} \
        --accession-table ${accession_table} \
        --seq-type ${seq_version} \
        --output-file ${seq_version}.histogram.txt
    """
}

process get_domain_length_histogram {
    input:
        path sequence_lengths
        val seq_version
    output:
        tuple val("${seq_version}_domain"), path("${seq_version}_domain.histogram.txt")

    script:
    """
    python $projectDir/../shared/visualization/compute_length_histogram.py \
        --length-mapping ${sequence_lengths} \
        --output-file ${seq_version}_domain.histogram.txt
    """
}

process compute_sequence_lengths {
    input:
        path fasta_lengths_parquet
        path accession_table
        path sequence_metadata
    output:
        path 'uniprot_lengths.tab', emit: 'expanded_uniprot'
        path 'fasta_lengths.tab', emit: 'fasta_lengths'

    script:
    """
    perl $projectDir/visualization/retrieve_sequence_lengths.pl \
        --fasta-lengths-parquet ${fasta_lengths_parquet} \
        --fasta-lengths fasta_lengths.tab \
        --accession-table ${accession_table} \
        --sequence-metadata ${sequence_metadata} \
        --uniprot-lengths uniprot_lengths.tab \
        --config ${params.efi_config} \
        --db-name ${params.efi_db}
    """
}

workflow REPORTING {
    take:
        blast_parquet
        fasta_lengths_parquet
        fasta_file
        accession_table
        import_stats
        sequence_metadata

    main:
        seq_versions = ['uniprot']
        if (params.sequence_version == "uniref50") {
            seq_versions = ["uniprot", "uniref50"]
        } else if (params.sequence_version == "uniref90") {
            seq_versions = ["uniprot", "uniref90"]
        }
        seq_version_ch = Channel.fromList(seq_versions)

        sequence_lengths = compute_sequence_lengths(fasta_lengths_parquet, accession_table, sequence_metadata)
        length_histograms = get_length_histogram(sequence_lengths.expanded_uniprot, accession_table, seq_version_ch)

        // Create a separate mapping file for domain lengths
        if (params.domain) {
            domain_length_histogram = get_domain_length_histogram(sequence_lengths.fasta_lengths, params.sequence_version)
            merged_length_histograms = length_histograms.concat(domain_length_histogram)
        } else {
            merged_length_histograms = length_histograms
        }

        stats = compute_stats(blast_parquet, fasta_lengths_parquet)

        boxplot_viz = visualize_boxplot_stats(stats.boxplot_stats)
        histo_viz = visualize_length_histograms(merged_length_histograms)

        files_to_merge_stream = import_stats.mix(stats.stats)
        files_to_merge = files_to_merge_stream.collect()
        final_stats = merge_stats(files_to_merge)

    emit:
        evalue_tab = stats.evaluetab
        final_stats
        boxplot_json = boxplot_viz.json.collect()
        boxplot_plots = boxplot_viz.plots.collect()
        histo_json = histo_viz.json.collect()
        histo_plots = histo_viz.plots.collect()
}

