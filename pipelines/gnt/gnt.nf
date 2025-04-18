include { color_and_retrieve } from "../shared/nextflow/color_workflow.nf"
cluster_data_dir = "cluster-data"

process create_gnns {
    publishDir params.final_output_dir, mode: "copy"
    publishDir "${params.final_output_dir}/${cluster_data_dir}/nb_pfam", pattern: "*.txt", mode: "copy"
    input:
        path cluster_id_map
        path singletons
    output:
        path "cluster_gnn.xgmml", emit: "cluster_gnn"
        path "pfam_gnn.xgmml", emit: "pfam_gnn"
        path "hub_count.txt", emit: "hub_count"
        path "cooc_table.txt", emit: "cooc_table"
        path "nomatches_noneighbors.txt", emit: "nomatches_noneighbors"
        path "gnd.sqlite", emit: "gnd"
        path "nb_pfam/pfam", emit: "nb_pfam"
        path "nb_pfam/all_pfam", emit: "nb_all_pfam"
        path "nb_pfam/pfam_split", emit: "nb_pfam_split"
        path "nb_pfam/all_pfam_split", emit: "nb_all_pfam_split"
        path "nb_pfam/no_fam", emit: "nb_no_pfam"

    """
    id_map_file="merged_ids.txt"
    cat ${cluster_id_map} > \$id_map_file
    awk '{if(NR>1)print}' ${singletons} >> \$id_map_file
    perl $projectDir/create_gnns.pl \
        --cluster-map \$id_map_file \
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
        --db-name ${params.efi_db}
    """
}

process color_gnt_ssn {
    publishDir params.final_output_dir, mode: "copy"
    input:
        path ssn_file
        path cluster_id_map
        path cluster_num_map
        path cluster_colors
        path metanode_map
        path gnd
    output:
        path "color_ssn.xgmml", emit: "ssn_output"
    """
    perl $projectDir/color_gnt_xgmml.pl --ssn $ssn_file --color-gnt-ssn color_ssn.xgmml \
        --metanode-map ${metanode_map} --gnd ${gnd} --cluster-map $cluster_id_map \
        --cluster-num-map $cluster_num_map --cluster-color-map cluster_colors.txt
    """
}

workflow {
    // Files are published to params.final_output_dir by the processes inside the
    // color_and_retrieve workflow
    color_work = color_and_retrieve()

    gnn_data = create_gnns(color_work.cluster_id_map, color_work.singletons)

    // Color the SSN based on the computed clusters and add ENA data
    colored_ssn = color_gnt_ssn(color_work.ssn_file, color_work.cluster_id_map, color_work.cluster_num_map, color_work.cluster_colors, color_work.metanode_map, gnn_data.gnd)
}

