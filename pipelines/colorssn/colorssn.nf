
include { COLOR_AND_RETRIEVE } from "../shared/nextflow/color_workflow.nf"
include { merge_stats; unzip_ssn; zip_files } from "../shared/nextflow/util.nf"
include { color_ssn } from "../shared/nextflow/color_xgmml.nf"


workflow {
    if (params.ssn_input =~ /\.zip$/) {
        ssn_file = unzip_ssn(Channel.value(file(params.ssn_input)))
    } else {
        ssn_file = Channel.value(file(params.ssn_input))
    }

    // Files are published to params.final_output_dir by the processes inside the
    // COLOR_AND_RETRIEVE workflow
    color_work = COLOR_AND_RETRIEVE(ssn_file)

    // Color the SSN based on the computed clusters
    colored_ssn = color_ssn(color_work.ssn_file, color_work.cluster_id_map, color_work.cluster_num_map, color_work.cluster_colors)

    // Zip SSN file
    zipped_files = zip_files(colored_ssn.ssn)

    stats_merge = color_work.cluster_stats.mix(colored_ssn.stats)
    stats_merge.collect().set { files_to_merge }
    final_stats = merge_stats(files_to_merge)
}

