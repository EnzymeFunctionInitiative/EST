
process make_histograms {
    tag "ca_histo_${type}_${id}"

    publishDir "${params.final_output_dir}/data/${type}/histo", mode: "copy"

    input:
        tuple val(type), val(id), path(fasta), val(sequence_type)

    output:
        tuple val(type), val(id), path("length_histogram*.png"), val(sequence_type)

    script:
    """
    python $projectDir/../shared/python/compute_length_histogram.py --fasta-file ${fasta} --output-file histogram.txt
    python $projectDir/../shared/python/plot_length_data.py --lengths histogram.txt --title "Number of Sequences at Each Length Full (${id}, ${sequence_type})" --frac 1 --plot-filename length_histogram_${id} --output-type png --proxies sm:48
    """
}

