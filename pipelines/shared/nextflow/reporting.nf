
process visualize_length_histograms {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path length_histogram_file
    output:
        path '*.json', emit: json
        path '*.png', emit: plots
    script:
    """
    base_name=\$(basename "${length_histogram_file}" .histogram.txt)
    python $projectDir/../shared/python/plot_length_data.py \
        --lengths $length_histogram_file \
        --job-id ${params.job_id} \
        --frac 1 \
        --plot-filename length_histogram_\${base_name} \
        --output-type png \
        --proxies sm:48
    python $projectDir/visualization/export_length_histogram_json.py \
        --lengths $length_histogram_file \
        --frac 1 \
        --output-json-filename length_histogram_\${base_name}.json 
    """
}

