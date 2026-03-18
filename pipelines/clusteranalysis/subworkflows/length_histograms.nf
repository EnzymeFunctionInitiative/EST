
// This process makes histograms for all sequence types that are provided, not just the SSN source
// sequences.
process MAKE_HISTOGRAMS {
    tag "ca_histo_${type}_${id}"

    publishDir "${params.final_output_dir}/data/histo/${type}", mode: "copy"

    input:
        tuple val(type), val(id), path(fasta), val(sequence_type)

    output:
        tuple path("*.png")

    script:
    """
    python $projectDir/../shared/python/compute_length_histogram.py --fasta-file ${fasta} --output-file histogram.txt
    python $projectDir/../shared/python/plot_length_data.py --lengths histogram.txt --title "Number of Sequences at Each Length Full (${id}, ${sequence_type})" --frac 1 --plot-filename ${id} --output-type png --proxies sm:48
    """
}

