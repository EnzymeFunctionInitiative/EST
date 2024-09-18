
process get_id_list {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path cluster_id_mapping
    output:
        path 'id_lists/', emit: 'id_lists'
    """
    mkdir id_lists
    #TODO get all of the IDs from the input cluster mapping file and save them to a directory, separated out by cluster number
    echo 'AAA' > id_lists/aaa.txt
    echo 'BBB' > id_lists/bbb.txt
    echo 'CCC' > id_lists/ccc.txt
    """
}

process get_fasta {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path id_list_dir
    output:
        path 'fasta/', emit: 'fasta'
    """
    mkdir fasta
    #TODO: get sequences from fasta database for the input IDs
    """
}

process color_ssn {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path ssn_file
        path cluster_id_mapping
        path cluster_sizes
    output:
        path 'ssn_colored.xgmml', emit: 'ssn_output'
    """
    perl $projectDir/../shared/perl/color_xgmml.pl --ssn $ssn_file --color-ssn ssn_colored.xgmml --cluster-map $cluster_id_mapping --cluster-size $cluster_sizes
    """
}

process get_ssn_id_info {
    input:
        path ssn_file
    output:
        path 'edgelist.txt', emit: 'edgelist'
        path 'index_seqid_map.txt', emit: 'index_seqid_mapping'
        path 'id_index_map.txt', emit: 'id_index_mapping'
    """
    perl $projectDir/../shared/perl/ssn_to_id_list.pl --ssn $ssn_file --edgelist edgelist.txt --index-seqid index_seqid_map.txt --id-index id_index_map.txt
    """
}

process unzip_input {
    input:
        path ssn_zipped
    output:
        path "ssn.xgmml"
    """
    perl $projectDir/../shared/perl/unzip_xgmml_file.pl --in $ssn_zipped --out ssn.xgmml
    """
}

process get_annotated_mapping_table {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path cluster_id_mapping
    output:
        path 'mapping_table.txt', emit: 'mapping_table'
    """
    #TODO
    touch mapping_table.txt
    """
}

process get_swissprot_tables {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path cluster_id_mapping
    output:
        path 'swissprot_clusters_desc.txt', emit: 'clusters'
        path 'swissprot_singletons_desc.txt', emit: 'singletons'
    """
    #TODO
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
    #TODO
    touch conv_ratio.txt
    """
}

process get_cluster_stats {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path cluster_id_mapping
    output:
        path 'stats.txt', emit: 'stats'
        path 'cluster_sizes.txt', emit: 'cluster_sizes'
        path 'cluster_num_map.txt', emit: 'cluster_num_map'
    """
    #TODO
    touch stats.txt
    touch cluster_sizes.txt
    touch cluster_num_map.txt
    """
}

process compute_clusters {
    input:
        path edgelist
        path index_seqid_mapping
    output:
        path 'cluster_id_map.txt', emit: 'cluster_id_mapping'
        path 'cluster_size_map.txt', emit: 'cluster_sizes'
    """
    python $projectDir/../shared/python/compute_clusters.py --edgelist $edgelist --index-seqid-map $index_seqid_mapping --clusters cluster_id_map.txt --cluster-info cluster_size_map.txt
    """
}

workflow color_and_retrieve {
    main:
        if (params.ssn_input =~ /\.zip/) {
            ssn_file = unzip_input(params.ssn_input)
        } else {
            ssn_file = params.ssn_input
        }

        // Get the index and ID mapping tables and edgelist
        ssn_data = get_ssn_id_info(ssn_file)

        // Compute the clusters
        compute_info = compute_clusters(ssn_data.edgelist, ssn_data.index_seqid_mapping)

        // Color the SSN based on the computed clusters
        colored_ssn = color_ssn(ssn_file, compute_info.cluster_id_mapping, compute_info.cluster_sizes)

        id_list_dir = get_id_list(compute_info.cluster_id_mapping)

        fasta_dir = get_fasta(id_list_dir)

        mapping_table = get_annotated_mapping_table(compute_info.cluster_id_mapping)

        sp_data = get_swissprot_tables(compute_info.cluster_id_mapping)

        cr_table = get_conv_ratio_table(compute_info.cluster_id_mapping)

        cluster_data = get_cluster_stats(compute_info.cluster_id_mapping)

    emit:
        ssn_file
        ssn_output = colored_ssn
        id_list_dir
        fasta_dir
        mapping_table
        sp_clusters = sp_data.clusters
        sp_singletons = sp_data.singletons
        cr_table
        cluster_stats = cluster_data.stats
        cluster_sizes = cluster_data.cluster_sizes
        cluster_num_map = cluster_data.cluster_num_map
}

