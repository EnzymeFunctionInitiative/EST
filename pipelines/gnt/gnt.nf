
include { color_and_retrieve } from "../shared/nextflow/color_workflow.nf"
include { zip_files; merge_stats } from "../shared/nextflow/util.nf"

cluster_data_dir = "cluster-data"


process create_gnns {
    //publishDir params.final_output_dir, mode: "copy", pattern: "{cluster_gnn.xgmml,pfam_gnn.xgmml,hub_count.txt,cooc_table.txt,nomatches_noneighbors.txt,gnd.sqlite}"
    publishDir params.final_output_dir, mode: "copy", pattern: "{hub_count.txt,cooc_table.txt,nomatches_noneighbors.txt,gnd.sqlite}"

    input:
        path cluster_id_map
        path singletons
        path metanode_map
        path ssn_file

    output:
        path "cluster_gnn.xgmml", emit: "cluster_gnn"
        path "pfam_gnn.xgmml", emit: "pfam_gnn"
        path "hub_count.txt", emit: "hub_count"
        path "cooc_table.txt", emit: "cooc_table"
        path "nomatches_noneighbors.txt", emit: "nomatches_noneighbors"
        path "gnd.sqlite", emit: "gnd"
        path "nb_pfam/neighbor_pfam", emit: "nb_pfam"
        path "nb_pfam/neighbor_pfam_all", emit: "nb_all_pfam"
        path "nb_pfam/neighbor_pfam_split", emit: "nb_pfam_split"
        path "nb_pfam/neighbor_pfam_all_split", emit: "nb_all_pfam_split"
        path "nb_pfam/neighbor_pfam_no_fam", emit: "nb_no_pfam"
        path "gnn_stats.json", emit: "stats"

    script:
    """
    id_map_file="merged_ids.txt"
    cat ${cluster_id_map} > \$id_map_file
    awk '{if(NR>1)print}' ${singletons} >> \$id_map_file
    perl $projectDir/create_gnns.pl \
        --cluster-map \$id_map_file \
        --metanode-map $metanode_map \
        --cluster-gnn cluster_gnn.xgmml \
        --pfam-gnn pfam_gnn.xgmml \
        --gnd gnd.sqlite \
        --cooc-table cooc_table.txt \
        --hub-count hub_count.txt \
        --nb-pfam-list-dir nb_pfam \
        --no-context nomatches_noneighbors.txt \
        --nb-size ${params.nb_size} \
        --cooc-threshold ${params.cooc_threshold} \
        --config ${params.efi_config} \
        --db-name ${params.efi_db} \
        --stats gnn_stats.json \
        --ssn $ssn_file
    """
}


process color_gnt_ssn {
    input:
        path ssn_file
        path cluster_id_map
        path cluster_num_map
        path cluster_colors
        path metanode_map
        path gnd

    output:
        path "color_ssn.xgmml", emit: "ssn"
        path "color_ssn_stats.json", emit: "stats"

    script:
    """
    perl $projectDir/color_gnt_xgmml.pl --ssn $ssn_file --color-gnt-ssn color_ssn.xgmml \
        --metanode-map ${metanode_map} --gnd ${gnd} --cluster-map $cluster_id_map \
        --cluster-num-map $cluster_num_map --cluster-color-map cluster_colors.txt \
        --stats color_ssn_stats.json
    """
}


process zip_directories {
    publishDir params.final_output_dir, mode: "copy"

    input:
        path dir_to_zip

    output:
        path "*.zip"

    script:
    """
    zip -r "${dir_to_zip}.zip" "${dir_to_zip}"
    """
}


workflow {
    // Files are published to params.final_output_dir by the processes inside the
    // color_and_retrieve workflow
    color_work = color_and_retrieve()

    // Compute the GNN and GND data and create the GNN XGMML files
    gnn_data = create_gnns(color_work.cluster_id_map, color_work.singletons, color_work.metanode_map, color_work.ssn_file)

    // Color the SSN based on the computed clusters and add ENA data
    colored_ssn = color_gnt_ssn(color_work.ssn_file, color_work.cluster_id_map, color_work.cluster_num_map, color_work.cluster_colors, color_work.metanode_map, gnn_data.gnd)

    // Zip up nb_pfam directories
    dirs_to_zip = gnn_data.nb_pfam.mix(gnn_data.nb_all_pfam,
                                       gnn_data.nb_pfam_split,
                                       gnn_data.nb_all_pfam_split,
                                       gnn_data.nb_no_pfam)
    zipped_dirs = zip_directories(dirs_to_zip)

    // Zip other output files
    files_to_zip = colored_ssn.ssn.mix(gnn_data.cluster_gnn,
                                       gnn_data.pfam_gnn,
                                       gnn_data.gnd)
    zipped_files = zip_files(files_to_zip)

    // Merge statistics from all of the various job types into one file
    files_to_merge_stream = gnn_data.stats.mix(colored_ssn.stats, color_work.cluster_stats)
    files_to_merge_stream.collect().set { files_to_merge }
    stats = merge_stats(files_to_merge)
}

