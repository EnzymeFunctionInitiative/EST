
include { prepareSsnFilename; unzip_ssn } from "../shared/nextflow/util.nf"

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

process color_by_connectivity {
    publishDir params.final_output_dir, mode: "copy", pattern: "{stats.json}"

    input:
        path ssn_file
        path nc_table

    output:
        path "*NC_Colored_SSN.xgmml", emit: "ssn"
        path "stats.json", emit: "stats"

    script:
    def default_name = "NC Colored SSN"
    def file_name = prepareSsnFilename(default_name)
    """
    perl $projectDir/color/color_ssn.pl \
        --input ${ssn_file} \
        --output ssn.xgmml \
        --color-map ${nc_table} \
        --primary-color \
        --stats stats.json
    zip color_ssn.xgmml.zip "${file_name}"
    """
}

process make_nc_legend {
    publishDir params.final_output_dir, mode: "copy", pattern: "{legend.png}"

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

workflow {
    if (params.ssn_input =~ /\.zip$/) {
        ssn_file = unzip_ssn(params.ssn_input)
    } else {
        ssn_file = params.ssn_input
    }

    nc_table = compute_connectivity_from_ssn(ssn_file)

    colored = color_by_connectivity(ssn_file, nc_table)

    legend = make_nc_legend(nc_table)
}

