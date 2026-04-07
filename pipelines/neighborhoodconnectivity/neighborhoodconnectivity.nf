
include { zip_files; unzip_ssn } from "../shared/nextflow/util.nf"

process compute_connectivity {
    publishDir params.final_output_dir, mode: "copy", pattern: "{nc.tab}"

    input:
        path ssn_file

    output:
        path "nc.tab", emit: "nc_table"

    script:
    """
    perl $projectDir/connectivity/get_connectivity.pl \
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

process make_legend {
    publishDir params.final_output_dir, mode: "copy", pattern: "{legend.png}"

    // In case the required Perl modules are not installed
    errorStrategy 'ignore'

    input:
        path nc_table

    output:
        path "legend.png", emit: "legend"

    script:
    """
    perl $projectDir/color/make_color_ramp.pl \
        --input ${nc_table} \
        --output legend.png
    """
}

workflow {
    if (params.ssn_input =~ /\.zip$/) {
        ssn_file = unzip_ssn(params.ssn_input)
    } else {
        ssn_file = params.ssn_input
    }

    nc_table = compute_connectivity(ssn_file)

    colored = color_by_connectivity(ssn_file, nc_table)

    legend = make_legend(nc_table)

    zipped_files = zip_files(colored.ssn)
}

