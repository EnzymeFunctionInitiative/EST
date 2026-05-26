
include { compute_connectivity_from_ssn; make_legend } from "../shared/nextflow/connectivity.nf"
include { zip_files; unzip_ssn } from "../shared/nextflow/util.nf"

process color_by_connectivity {
    publishDir params.final_output_dir, mode: "copy", pattern: "{stats.json}"

    input:
        path ssn_file
        path nc_table

    output:
        path "ssn.xgmml", emit: "ssn"
        path "stats.json", emit: "stats"

    script:
    """
    perl $projectDir/color/color_ssn.pl \
        --input ${ssn_file} \
        --output ssn.xgmml \
        --color-map ${nc_table} \
        --primary-color \
        --stats stats.json
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

    legend = make_legend(nc_table)

    zipped_files = zip_files(colored.ssn)
}

