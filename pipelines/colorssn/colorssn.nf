
include { color_and_retrieve } from "../shared/nextflow/color_workflow.nf"
include { merge_stats; zip_files } from "../shared/nextflow/util.nf"

process color_ssn {
    input:
        path ssn_file
        path cluster_id_map
        path cluster_num_map
        path cluster_colors

    output:
        path "color_ssn.xgmml", emit: "ssn"
        path "color_stats.json", emit: "stats"

    script:
    """
    perl $projectDir/color_xgmml.pl --ssn $ssn_file --color-ssn color_ssn.xgmml \
        --cluster-map $cluster_id_map --cluster-num-map $cluster_num_map --cluster-color-map $cluster_colors \
        --stats color_stats.json
    """
}


workflow {
    // Files are published to params.final_output_dir by the processes inside the
    // color_and_retrieve workflow
    color_work = color_and_retrieve()

    // Color the SSN based on the computed clusters
    colored_ssn = color_ssn(color_work.ssn_file, color_work.cluster_id_map, color_work.cluster_num_map, color_work.cluster_colors)

    // Zip SSN file
    zipped_files = zip_files(colored_ssn.ssn)

    stats_merge = color_work.cluster_stats.mix(colored_ssn.stats)
    stats_merge.collect().set { files_to_merge }
    final_stats = merge_stats(files_to_merge)
}

