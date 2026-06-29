
include { prepareSsnFilename } from "./util.nf"

process color_ssn {
    input:
        path ssn_file
        path cluster_id_map
        path cluster_num_map
        path cluster_colors

    output:
        path "*Colored_SSN.xgmml", emit: "ssn"
        path "color_stats.json", emit: "stats"

    script:
    def file_name = prepareSsnFilename("Colored SSN")
    """
    perl $projectDir/../shared/perl/color_xgmml.pl --ssn $ssn_file --color-ssn ${file_name} \
        --cluster-map $cluster_id_map --cluster-num-map $cluster_num_map --cluster-color-map $cluster_colors \
        --stats color_stats.json
    """
}

