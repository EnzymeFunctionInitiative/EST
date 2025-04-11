
include { unzip_ssn } from "./unzip.nf"

cluster_data_dir = "cluster-data"

process get_id_list {
    publishDir "${params.final_output_dir}/${cluster_data_dir}/id_lists", pattern: "*.txt", mode: "copy"
    input:
        path cluster_id_map
        path singletons
        path seqid_source_map
    output:
        path "cluster_sizes.txt", emit: "cluster_sizes"
        tuple val("uniprot"), path("uniprot/*.txt"), emit: "uniprot"
        tuple val("uniref90"), path("uniref90/*.txt", arity: "0..*"), emit: "uniref90"
        tuple val("uniref50"), path("uniref50/*.txt", arity: "0..*"), emit: "uniref50"
    """
    id_list_dir="."
    perl $projectDir/../shared/perl/get_id_lists.pl --cluster-map $cluster_id_map --singletons $singletons \
        --uniprot \$id_list_dir/uniprot --uniref90 \$id_list_dir/uniref90 --uniref50 \$id_list_dir/uniref50 \
        --seqid-source-map $seqid_source_map --cluster-sizes cluster_sizes.txt \
        --config ${params.efi_config} --db-name ${params.efi_db}
    """
}

process get_fasta {
    publishDir "${params.final_output_dir}/${cluster_data_dir}/fasta/$version", mode: "copy"
    input:
        tuple val(version), path(id_file)
    output:
        tuple val(version), path("*.fasta", arity: "1")
    """
    base_filename=\$(basename $id_file .txt)
    fasta_file="\${base_filename}.fasta"
    perl $projectDir/../shared/perl/get_sequences.pl --fasta-db ${params.fasta_db} --sequence-ids-file ${id_file} --output-sequence-file \${fasta_file}
    """
}

process get_ssn_id_info {
    publishDir params.final_output_dir, mode: "copy"
    input:
        path ssn_file
    output:
        path "edgelist.txt", emit: "edgelist"
        path "index_seqid_map.txt", emit: "index_seqid_map"
        path "id_index_map.txt", emit: "id_index_map"
        path "seqid_source_map.txt", emit: "seqid_source_map"
        path "ssn_sequences.fasta", emit: "ssn_sequences"
    """
    perl $projectDir/../shared/perl/ssn_to_id_list.pl --ssn $ssn_file --edgelist edgelist.txt --index-seqid index_seqid_map.txt \
        --id-index id_index_map.txt --seqid-source-map seqid_source_map.txt --ssn-sequences ssn_sequences.fasta
    """
}

process get_annotated_mapping_tables {
    publishDir params.final_output_dir, mode: "copy"
    input:
        path cluster_id_map
        path seqid_source_map
        path cluster_color_map
    output:
        path "mapping_table.txt", emit: "mapping_table"
        path "swissprot_clusters_desc.txt", emit: "swissprot_table"
    """
    perl $projectDir/../shared/perl/annotate_mapping_table.pl --seqid-source-map $seqid_source_map --cluster-map $cluster_id_map \
        --cluster-color-map $cluster_color_map --mapping-table mapping_table.txt --swissprot-table swissprot_clusters_desc.txt \
        --config ${params.efi_config} --db-name ${params.efi_db}
    """
}

process get_conv_ratio_table {
    publishDir params.final_output_dir, mode: "copy"
    input:
        path edgelist
        path index_seqid_map
        path cluster_id_map
        path seqid_source_map
    output:
        path "conv_ratio.txt", emit: "conv_ratio"
    """
    perl $projectDir/../shared/perl/compute_conv_ratio.pl --cluster-map $cluster_id_map --index-seqid-map $index_seqid_map \
        --edgelist $edgelist --seqid-source-map $seqid_source_map --conv-ratio conv_ratio.txt
    """
}

process get_cluster_stats {
    publishDir params.final_output_dir, mode: "copy"
    input:
        path cluster_id_map
        path seqid_source_map
        path singletons
    output:
        path "stats.txt", emit: "stats"
    """
    perl $projectDir/../shared/perl/compute_stats.pl --cluster-map $cluster_id_map --seqid-source-map $seqid_source_map \
        --singletons $singletons --stats stats.txt
    """
}

process compute_clusters {
    publishDir params.final_output_dir, mode: "copy"
    input:
        path edgelist
        path index_seqid_map
    output:
        path "cluster_id_map.txt", emit: "cluster_id_map"
        path "singletons.txt", emit: "singletons"
        path "cluster_num_map.txt", emit: "cluster_num_map"
    """
    python $projectDir/../shared/python/compute_clusters.py --edgelist $edgelist --index-seqid-map $index_seqid_map \
        --clusters cluster_id_map.txt --singletons singletons.txt --cluster-num-map cluster_num_map.txt
    """
}

process assign_cluster_colors {
    input:
        path cluster_num_map
    output:
        path "cluster_colors.txt", emit: "cluster_colors"
    """
    perl $projectDir/../shared/perl/assign_cluster_colors.pl --cluster-num-map ${cluster_num_map} \
        --cluster-color-map cluster_colors.txt
    """
}

workflow color_and_retrieve {
    main:
        if (params.ssn_input =~ /\.zip$/) {
            ssn_file = unzip_ssn(params.ssn_input)
        } else {
            ssn_file = params.ssn_input
        }

        // Get the index and ID mapping tables and edgelist
        ssn_data = get_ssn_id_info(ssn_file)

        // Compute the clusters
        compute_info = compute_clusters(ssn_data.edgelist, ssn_data.index_seqid_map)

        id_list_data = get_id_list(compute_info.cluster_id_map, compute_info.singletons, ssn_data.seqid_source_map)
        id_list = id_list_data.uniprot.transpose().concat(id_list_data.uniref90.transpose(), id_list_data.uniref50.transpose())

        get_fasta(id_list)

        cluster_colors = assign_cluster_colors(compute_info.cluster_num_map)

        anno_tables = get_annotated_mapping_tables(compute_info.cluster_id_map, ssn_data.seqid_source_map, cluster_colors)

        cr_table = get_conv_ratio_table(ssn_data.edgelist, ssn_data.index_seqid_map, compute_info.cluster_id_map, ssn_data.seqid_source_map)

        cluster_data = get_cluster_stats(compute_info.cluster_id_map, ssn_data.seqid_source_map, compute_info.singletons)

    emit:
        ssn_file
        cluster_data_dir = cluster_data_dir
        mapping_table = anno_tables.mapping_table
        sp_clusters = anno_tables.swissprot_table
        cr_table
        cluster_stats = cluster_data.stats
        cluster_sizes = id_list_data.cluster_sizes
        cluster_num_map = compute_info.cluster_num_map
        cluster_id_map = compute_info.cluster_id_map
        singletons = compute_info.singletons
        metanode_map = ssn_data.seqid_source_map
        cluster_colors
}

