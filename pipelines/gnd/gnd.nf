
process create_gnd {
    publishDir params.final_output_dir, mode: "copy"
    input:
        path cluster_id_map
    output:
        path "gnd.sqlite", emit: "gnd"

    """
    perl $projectDir/create_gnd.pl \
        --config ${params.efi_config} \
        --db-name ${params.efi_db} \
        --cluster-map $cluster_id_map \
        --nb-size ${params.nb_size} \
        --gnd gnd.sqlite
    """
}

workflow {
    gnd = create_gnd(params.cluster_id_map)
}

