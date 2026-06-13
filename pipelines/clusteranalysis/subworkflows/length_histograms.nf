
// This process makes histograms for all sequence types that are provided, not just the SSN source
// sequences.
process MAKE_HISTOGRAMS {
    tag "ca_histo_${type}_${id}"
    publishDir "${params.final_output_dir}/data/histo/${type}", mode: "copy"

    input:
        tuple val(type), val(id), path(fasta), val(sequence_type)
    output:
        path("${id}.png")
        path("${id}_sm.png")

    script:
    """
    python $projectDir/../shared/visualization/compute_length_histogram.py \
        --fasta-file ${fasta} \
        --output-file histogram.txt
    if [[ -f "histogram.txt" && -s "histogram.txt" ]]; then
        python $projectDir/../shared/visualization/plot_length_data.py \
            --lengths histogram.txt \
            --title "Number of Sequences at Each Length (${id}, ${sequence_type})" \
            --frac 1 \
            --plot-filename ${id} \
            --output-type png \
            --proxies sm:48
    else
        echo "Data for length histogram does not exist for ${id}; skipping"
    fi
    """
}

