include { color_and_retrieve } from "../shared/nextflow/color_workflow.nf"

process color_ssn {
    publishDir params.final_output_dir, mode: "copy"
    input:
        path ssn_file
        path cluster_id_map
        path cluster_num_map
        path cluster_colors
    output:
        path "color_ssn.xgmml", emit: "ssn_output"
    """
    perl $projectDir/color_xgmml.pl --ssn $ssn_file --color-ssn color_ssn.xgmml \
        --cluster-map $cluster_id_map --cluster-num-map $cluster_num_map --cluster-color-map $cluster_colors
    """
}

workflow {
    // Files are published to params.final_output_dir by the processes inside the
    // color_and_retrieve workflow
    color_work = color_and_retrieve()

    // Color the SSN based on the computed clusters
    colored_ssn = color_ssn(color_work.ssn_file, color_work.cluster_id_map, color_work.cluster_num_map, color_work.cluster_colors)
}

