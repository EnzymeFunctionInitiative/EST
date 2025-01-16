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
    cat $cluster_id_map $singletons > \$id_map_file
    perl $projectDir/create_gnns.pl \
        --config ${params.efi_config} --db-name ${params.efi_db} --cluster-map \$id_map_file \
        --cluster-gnn cluster_gnn.xgmml --pfam-gnn pfam_gnn.xgmml \
        --hub-count hub_count.txt --cooc-table cooc_table.txt --no-context nomatches_noneighbors.txt \
        --nb-pfam-list-dir nb_pfam --gnd gnd.sqlite
    """
}

workflow {
    // Files are published to params.final_output_dir by the processes inside the
    // color_and_retrieve workflow
    color_work = color_and_retrieve()

    gnn_data = create_gnns(color_work.cluster_id_map, color_work.singletons)
}

