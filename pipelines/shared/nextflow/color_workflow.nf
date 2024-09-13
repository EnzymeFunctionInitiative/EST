include { unzip_input } from "./unzip.nf"
include { get_id_list } from "./get_id_list.nf"
include { color_ssn } from "./color_ssn.nf"
include { get_annotated_mapping_table; get_swissprot_tables; get_conv_ratio_table; get_cluster_stats } from "./util.nf"

workflow color_and_retrieve {
    main:
        if (params.ssn_input =~ /\.zip/) {
            ssn_file = unzip_input(params.ssn_input)
        } else {
            ssn_file = params.ssn_input
        }

        color_data = color_ssn(ssn_file)

        id_lists = get_id_list(color_data.id_list)

        mapping_table = get_annotated_mapping_table(color_data.id_list)

        sp_data = get_swissprot_tables(color_data.id_list)

        cr_table = get_conv_ratio_table(mapping_table)

        cluster_data = get_cluster_stats(color_data.id_list)

    emit:
        ssn_file
        ssn_output = color_data.ssn_output
        id_list = color_data.id_list
        id_lists
        mapping_table
        sp_clusters = sp_data.clusters
        sp_singletons = sp_data.singletons
        cr_table
        cluster_stats = cluster_data.stats
        cluster_sizes = cluster_data.cluster_sizes
        cluster_num_map = cluster_data.cluster_num_map
}

