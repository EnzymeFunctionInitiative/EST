
cluster_data_dir = 'cluster-data'

process get_id_list {
    publishDir "$params.final_output_dir", pattern: "$cluster_data_dir/id_lists/uniprot/*.txt", mode: 'copy'
    publishDir "$params.final_output_dir", pattern: "$cluster_data_dir/id_lists/uniref90/*.txt", mode: 'copy'
    publishDir "$params.final_output_dir", pattern: "$cluster_data_dir/id_lists/uniref50/*.txt", mode: 'copy'
    input:
        path cluster_id_map
        path singletons
        path seqid_source_map
    output:
        path 'cluster_sizes.txt', emit: 'cluster_sizes'
        path "$cluster_data_dir/id_lists/*/*.txt", emit: 'id_lists'
    """
    id_list_dir="$cluster_data_dir/id_lists"
    perl $projectDir/../shared/perl/get_id_lists.pl --cluster-map $cluster_id_map --singletons $singletons \
        --uniprot \$id_list_dir/uniprot --uniref90 \$id_list_dir/uniref90 --uniref50 \$id_list_dir/uniref50 \
        --seqid-source-map $seqid_source_map --cluster-sizes cluster_sizes.txt \
        --config ${params.efi_config} --db-name ${params.efi_db}
    """
}

process get_fasta {
    publishDir (
        path: "$params.final_output_dir",
        mode: 'copy',
        pattern: '*.fasta',
        saveAs: {
            fn ->
                if (fn.contains("UniProt")) { "$cluster_data_dir/fasta/uniprot/${fn}" }
                else if (fn.contains("UniRef90")) { "$cluster_data_dir/fasta/uniref90/${fn}" }
                else if (fn.contains("UniRef50")) { "$cluster_data_dir/fasta/uniref50/${fn}" }
                else { "$cluster_data_dir/fasta/${fn}" }
        }
    )
    input:
        path id_file
    output:
        path '*.fasta', emit: 'fasta'
    """
    base_filename=\$(basename $id_file .txt)
    fasta_file="\${base_filename}.fasta"
    perl $projectDir/../shared/perl/get_sequences.pl --fasta-db ${params.fasta_db} --sequence-ids-file ${id_file} --output-sequence-file \${fasta_file}
    """
}

process color_ssn {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path ssn_file
        path cluster_id_map
        path cluster_num_map
    output:
        path 'ssn_colored.xgmml', emit: 'ssn_output'
        path 'cluster_colors.txt', emit: 'cluster_colors'
    """
    perl $projectDir/../shared/perl/color_xgmml.pl --ssn $ssn_file --color-ssn ssn_colored.xgmml --cluster-map $cluster_id_map \
        --cluster-num-map $cluster_num_map --cluster-color-map cluster_colors.txt --color-file $projectDir/../shared/perl/colors.tab
    """
}

process get_ssn_id_info {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path ssn_file
    output:
        path 'edgelist.txt', emit: 'edgelist'
        path 'index_seqid_map.txt', emit: 'index_seqid_map'
        path 'id_index_map.txt', emit: 'id_index_map'
        path 'seqid_source_map.txt', emit: 'seqid_source_map'
    """
    perl $projectDir/../shared/perl/ssn_to_id_list.pl --ssn $ssn_file --edgelist edgelist.txt --index-seqid index_seqid_map.txt \
        --id-index id_index_map.txt --seqid-source-map seqid_source_map.txt
    """
}

process unzip_input {
    input:
        path ssn_zipped
    output:
        path "ssn____local.xgmml"
    """
    perl $projectDir/../shared/perl/unzip_xgmml_file.pl --in $ssn_zipped --out ssn____local.xgmml
    """
}

process get_annotated_mapping_tables {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path cluster_id_map
        path seqid_source_map
        path cluster_color_map
    output:
        path 'mapping_table.txt', emit: 'mapping_table'
        path 'swissprot_clusters_desc.txt', emit: 'swissprot_table'
    """
    perl $projectDir/../shared/perl/annotate_mapping_table.pl --seqid-source-map $seqid_source_map --cluster-map $cluster_id_map \
        --cluster-color-map $cluster_color_map --mapping-table mapping_table.txt --swissprot-table swissprot_clusters_desc.txt \
        --config ${params.efi_config} --db-name ${params.efi_db}
    """
}

process get_conv_ratio_table {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path edgelist
        path index_seqid_map
        path cluster_id_map
        path seqid_source_map
    output:
        path 'conv_ratio.txt', emit: 'conv_ratio'
    """
    perl $projectDir/../shared/perl/compute_conv_ratio.pl --cluster-map $cluster_id_map --index-seqid-map $index_seqid_map \
        --edgelist $edgelist --seqid-source-map $seqid_source_map --conv-ratio conv_ratio.txt
    """
}

process get_cluster_stats {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path cluster_id_map
        path seqid_source_map
        path singletons
    output:
        path 'stats.txt', emit: 'stats'
    """
    perl $projectDir/../shared/perl/compute_stats.pl --cluster-map $cluster_id_map --seqid-source-map $seqid_source_map \
        --singletons $singletons --stats stats.txt
    """
}

process compute_clusters {
    input:
        path edgelist
        path index_seqid_map
    output:
        path 'cluster_id_map.txt', emit: 'cluster_id_map'
        path 'singletons.txt', emit: 'singletons'
        path 'cluster_num_map.txt', emit: 'cluster_num_map'
    """
    python $projectDir/../shared/python/compute_clusters.py --edgelist $edgelist --index-seqid-map $index_seqid_map \
        --clusters cluster_id_map.txt --singletons singletons.txt --cluster-num-map cluster_num_map.txt
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
        compute_info = compute_clusters(ssn_data.edgelist, ssn_data.index_seqid_map)

        id_list_data = get_id_list(compute_info.cluster_id_map, compute_info.singletons, ssn_data.seqid_source_map)

        get_fasta(id_list_data.id_lists.flatten())

        // Color the SSN based on the computed clusters
        colored_ssn = color_ssn(ssn_file, compute_info.cluster_id_map, compute_info.cluster_num_map)

        anno_tables = get_annotated_mapping_tables(compute_info.cluster_id_map, ssn_data.seqid_source_map, colored_ssn.cluster_colors)

        cr_table = get_conv_ratio_table(ssn_data.edgelist, ssn_data.index_seqid_map, compute_info.cluster_id_map, ssn_data.seqid_source_map)

        cluster_data = get_cluster_stats(compute_info.cluster_id_map, ssn_data.seqid_source_map, compute_info.singletons)

    emit:
        ssn_file
        ssn_output = colored_ssn.ssn_output
        cluster_data_dir = cluster_data_dir
        mapping_table = anno_tables.mapping_table
        sp_clusters = anno_tables.swissprot_table
        cr_table
        cluster_stats = cluster_data.stats
        cluster_sizes = id_list_data.cluster_sizes
        cluster_num_map = compute_info.cluster_num_map
}

