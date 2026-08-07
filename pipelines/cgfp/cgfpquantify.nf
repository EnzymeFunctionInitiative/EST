
include { merge_stats; prepareJobName; prepareSsnFilename; unzip_ssn } from "../shared/nextflow/util.nf"

process merge_results {
    publishDir params.final_output_dir, mode: "copy", pattern: "{*.txt}"

    input:
        path result_files
        path ssn_cluster_file
        val base_name
        val merge_type
    output:
        path "cluster_abundance${base_name}.txt", emit: "cluster"
        path "protein_abundance${base_name}.txt", emit: "protein"

    script:
    def merge_type_arg = ""
    if (merge_type == "normalized") {
        merge_type_arg = "-n"
    } else if (merge_type == "ags_normalized") {
        if (params.ags_normalization_file && file(params.ags_normalization_file).exists()) {
            merge_type_arg = "-g ${params.ags_normalization_file}"
        }
    }

    """
    python $projectDir/merge_shortbred.py \
        ${result_files} \
        -c ${ssn_cluster_file} \
        -C "cluster_abundance${base_name}.txt" \
        -p "protein_abundance${base_name}.txt" \
        ${merge_type_arg}
    """
}

process compute_quantify_stats {
    input:
        path protein_abundance
    output:
        path "quantify_stats.json"

    script:
    """
    perl $projectDir/prep/make_quantify_stats.pl \
        --protein-abundance ${protein_abundance} \
        --stats quantify_stats.json
    """
}

process create_quantify_ssn {
    publishDir params.final_output_dir, mode: "copy", pattern: "{quantify_ssn.xgmml.zip}"

    input:
        path ssn_file
        path protein_results
        path cluster_results
        path metagenome_db_dir
    output:
        path "quantify_ssn.xgmml.zip", emit: "quantify_ssn"

    script:
    def default_name = "ShortBRED Quantify"
    def final_job_name = prepareJobName(default_name)
    def file_name = prepareSsnFilename(default_name)
    def temp_name = "quantify_ssn.xgmml"

    def mg_ids = params.metagenome_ids.join(',')
    """
    perl $projectDir/create/create_quantify_ssn.pl \
        --input ${ssn_file} \
        --output ${temp_name} \
        --protein-results ${protein_results} \
        --cluster-results ${cluster_results} \
        --metagenome-ids ${mg_ids} \
        --metagenome-db "${metagenome_db_dir}" \
        --cdhit-file ${cdhit_file} \
        --title "${final_job_name}"
    cp ${temp_name} "${file_name}"
    zip quantify_ssn.xgmml.zip "${file_name}"
    rm "${file_name}"
    """
}

process cgfp_quantify {
    publishDir params.final_output_dir, mode: "copy", pattern: "{*.results.median,*.results.mean}"

    input:
        tuple val(mg_id), path(mg_file)
        path marker_file
    output:
        path "${mg_id}.results.median", emit: "results_median"
        path "${mg_id}.results.mean", emit: "results_mean"

    script:
    def search_program  = ""
    def sb_src          = ""
    if (params.sb_identify_method == "diamond") {
        search_program  = "--search_program diamond"
        sb_src          = "shortbred_diamond"
    } else if (params.sb_identify_method) {
        sb_src          = "shortbred_blast"
    }

    """
    SB_TEMP_DIR=quantify-temp/${mg_id}
    mkdir -p \$SB_TEMP_DIR

    python $projectDir/shortbred/${sb_src}/shortbred_quantify.py \
        --threads ${params.sb_quantify_threads} \
        --markers ${marker_file} \
        --wgs ${mg_file} \
        --results ${mg_id}.results.median \
        --results-mean ${mg_id}.results.mean \
        --tmp \$SB_TEMP_DIR \
        ${search_program}

    #TODO:
    #rm -rf \$SB_TEMP_DIR
    """
}

workflow {
    if (params.ssn_input =~ /\.zip$/) {
        ssn_file = unzip_ssn(Channel.value(file(params.ssn_input)))
    } else {
        ssn_file = Channel.value(file(params.ssn_input))
    }

    identify_stats = file(params.identify_stats)
    markers = file(params.identify_markers)
    cluster_file = file(params.identify_ssn_clusters)
    db_dir = file(params.metagenome_db_dir)

    metagenome_ids_ch = Channel.from(params.metagenome_ids)
    metagenome_files = metagenome_ids_ch
        .map { id ->
            def filePath = file("${params.metagenome_db_dir}/${id}")
            return tuple(id, filePath)
        }

    results = cgfp_quantify(metagenome_files, markers)

    median_results_ch       = results.results_median.collect()
    median_results          = merge_results(median_results_ch, cluster_file, "", "")
    median_norm_results     = merge_results(median_results_ch, cluster_file, "_normalized", "normalized")
    median_ags_norm_results = merge_results(median_results_ch, cluster_file, "_genome_normalized", "ags_normalized")

    mean_results_ch         = results.results_mean.collect()
    mean_results            = merge_results(mean_results_ch, cluster_file, "_mean", "")
    mean_norm_results       = merge_results(mean_results_ch, cluster_file, "_normalized_mean", "normalized")
    mean_ags_norm_results   = merge_results(mean_results_ch, cluster_file, "_genome_normalized_mean", "ags_normalized")

    create_quantify_ssn(ssn_file, median_ags_norm_results.protein, median_ags_norm_results.cluster, db_dir)

    stats = compute_quantify_stats(median_results.protein)

    files_to_merge_stream = identify_stats.mix(stats)
    files_to_merge = files_to_merge_stream.collect()

    merge_stats(files_to_merge)
}

