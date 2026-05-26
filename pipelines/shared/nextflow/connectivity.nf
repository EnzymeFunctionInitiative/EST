
process compute_connectivity_from_ssn {
    publishDir params.final_output_dir, mode: "copy", pattern: "{nc.tab}"

    input:
        path ssn_file

    output:
        path "nc.tab", emit: "nc_table"

    script:
    """
    python $projectDir/../shared/connectivity/get_connectivity.py \
        --input-xgmml ${ssn_file} \
        --output-map nc.tab
    """
}

process compute_connectivity_from_blast {
    publishDir params.final_output_dir, mode: "copy", pattern: "{nc.tab}"

    input:
        path blast_tsv
        path cdhit_clstr // Optional (if empty)

    output:
        path "nc.tab", emit: "nc_table"

    script:
    """
    CDHIT_ARG=""
    if [ -n "${cdhit_clstr}" ] && [ -f "${cdhit_clstr}" ]; then
        CDHIT_ARG="--cdhit ${cdhit_clstr}"
    fi

    python $projectDir/../shared/connectivity/get_connectivity.py \
        --input-blast ${blast_tsv} \
        \$CDHIT_ARG \
        --output-map nc.tab
    """
}

process make_nc_legend {
    publishDir params.final_output_dir, mode: "copy", pattern: "{legend.png}"

    // In case the required Perl modules are not installed
    errorStrategy 'ignore'

    input:
        path nc_table

    output:
        path "legend.png", emit: "legend"

    script:
    """
    python $projectDir/../shared/connectivity/make_color_ramp.py \
        --input-file ${nc_table} \
        --output-file legend.png
    """
}

