process unzip_input {
    input:
        path ssn_zipped
    output:
        path "ssn.xgmml"
    """
    perl $projectDir/src/colorssn/unzip_input/unzip_file.pl -in $ssn_zipped -out ssn.xgmml
    """
}

process cluster_gnn {
    input:
        path ssn_file
    output:
        path 'ssn_out.xgmml', emit: 'ssn_output'
        path 'mapping_table.txt', emit: 'mapping_table'
        path 'stats.txt', emit: 'stats'
        path 'conv_ratio.txt', emit: 'conv_ratio'
        path 'cluster_sizes.txt', emit: 'cluster_sizes'
        path 'cluster_num_map.txt', emit: 'cluster_num_map'
        path 'swissprot_clusters_desc.txt', emit: 'swissprot_clusters_desc'
        path 'swissprot_singletons_desc.txt', emit: 'swissprot_singletons_desc'
        path 'ssn-sequences.fa', emit: 'ssn_sequences'

        path 'cluster-data/uniprot-nodes', emit: 'uniprot_id_dir', optional: true
        path 'cluster-data/uniprot-domain-nodes', emit: 'uniprot_domain_nodes', optional: true
        path 'cluster-data/uniref50-nodes', emit: 'uniref50_id_dir', optional: true
        path 'cluster-data/uniref50-domain-nodes', emit: 'uniref50_domain_nodes', optional: true
        path 'cluster-data/uniref90-nodes', emit: 'uniref90_id_dir', optional: true
        path 'cluster-data/uniref90-domain-nodes', emit: 'uniref90_domain_nodes', optional: true
        path 'mapping_table_domain.txt', emit: 'mapping_table_domain', optional: true

    """
    perl $projectDir/src/colorssn/cluster_gnn/cluster_gnn.pl -output-dir . \
                                                             -ssnin $ssn_file \
                                                             -ssnout ssn_out.xgmml \
                                                             -uniprot-id-dir cluster-data/uniprot-nodes \
                                                             -uniprot-domain-id-dir cluster-data/uniprot-domain-nodes \
                                                             -uniref50-id-dir cluster-data/uniref50-nodes \
                                                             -uniref50-domain-id-dir cluster-data/uniref50-domain-nodes \
                                                             -uniref90-id-dir cluster-data/uniref90-nodes \
                                                             -uniref90-domain-id-dir cluster-data/uniref90-domain-nodes \
                                                             -id-out mapping_table.txt \
                                                             -id-out-domain mapping_table_domain.txt \
                                                             -config ${params.efi_config} \
                                                             -efi-db ${params.efi_db} \
                                                             -stats stats.txt \
                                                             -conv-ratio conv_ratio.txt \
                                                             -cluster-sizes cluster_sizes.txt \
                                                             -cluster-num-map cluster_num_map.txt \
                                                             -sp-clusters-desc swissprot_clusters_desc.txt \
                                                             -sp-singletons-desc swissprot_singletons_desc.txt
    """
}

workflow {
    if (params.ssn_input =~ /\.zip/) {
        ssn_file = unzip_input(params.ssn_input)
    } else {
        ssn_file = params.ssn_input
    }

    cluster_output = cluster_gnn(ssn_file)
}