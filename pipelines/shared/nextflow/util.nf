process get_annotated_mapping_table {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path id_list
    output:
        path 'mapping_table.txt', emit: 'mapping_table'
    """
    touch mapping_table.txt
    """
}

process get_swissprot_tables {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path id_list
    output:
        path 'swissprot_clusters_desc.txt', emit: 'clusters'
        path 'swissprot_singletons_desc.txt', emit: 'singletons'
    """
    touch swissprot_clusters_desc.txt
    touch swissprot_singletons_desc.txt
    """
}

process get_conv_ratio_table {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path mapping_table
    output:
        path 'conv_ratio.txt', emit: 'conv_ratio'
    """
    touch conv_ratio.txt
    """
}

process get_cluster_stats {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path id_list
    output:
        path 'stats.txt', emit: 'stats'
        path 'cluster_sizes.txt', emit: 'cluster_sizes'
        path 'cluster_num_map.txt', emit: 'cluster_num_map'
    """
    touch stats.txt
    touch cluster_sizes.txt
    touch cluster_num_map.txt
    """
}

