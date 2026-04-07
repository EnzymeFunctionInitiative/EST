
process color_ssn {
    input:
        path ssn_file
        path cluster_id_map
        path cluster_num_map
        path cluster_colors

    output:
        path "color_ssn.xgmml", emit: "ssn"
        path "color_stats.json", emit: "stats"

    script:
    """
    perl $projectDir/../shared/perl/color_xgmml.pl --ssn $ssn_file --color-ssn color_ssn.xgmml \
        --cluster-map $cluster_id_map --cluster-num-map $cluster_num_map --cluster-color-map $cluster_colors \
        --stats color_stats.json
    """
}

