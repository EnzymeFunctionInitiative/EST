
include { merge_stats; prepareJobName; prepareSsnFilename; unzip_ssn } from "../shared/nextflow/util.nf"
include { merge_results as merge_median_raw }      from './helper/merge_results.nf'
include { merge_results as merge_median_norm }     from './helper/merge_results.nf'
include { merge_results as merge_median_ags }      from './helper/merge_results.nf'
include { merge_results as merge_mean_raw }        from './helper/merge_results.nf'
include { merge_results as merge_mean_norm }       from './helper/merge_results.nf'
include { merge_results as merge_mean_ags }        from './helper/merge_results.nf'

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
    publishDir params.final_output_dir, mode: "copy", pattern: "{quantify_ssn.xgmml.zip,metagenome_desc.txt}"

    input:
        path ssn_file
        path protein_results
        path cluster_results
        path metagenome_db_dir
        path seqid_source_map
        path cdhit_table
    output:
        path "quantify_ssn.xgmml.zip", emit: "quantify_ssn"
        path "metagenome_desc.txt", emit: "metagenome_desc"

    script:
    def default_name = "ShortBRED Quantify"
    def final_job_name = prepareJobName(default_name)
    def file_name = prepareSsnFilename(default_name)
    def temp_name = "quantify_ssn.xgmml"
    """
    perl $projectDir/create/create_quantify_ssn.pl \
        --input ${ssn_file} \
        --output ${temp_name} \
        --protein-abundance ${protein_results} \
        --cluster-abundance ${cluster_results} \
        --metagenome-db "${metagenome_db_dir}" \
        --seqid-source-map ${seqid_source_map} \
        --cdhit-table ${cdhit_table} \
        --metagenome-desc metagenome_desc.txt \
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
        sb_src          = "${params.shortbred_src_dir}/shortbred_diamond"
    } else if (params.sb_identify_method) {
        sb_src          = "${params.shortbred_src_dir}/shortbred_blast"
    }

    """
    SB_TEMP_DIR=quantify-temp/${mg_id}
    mkdir -p \$SB_TEMP_DIR

    python ${sb_src}/shortbred_quantify.py \
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

    identify_stats = file("${params.identify_dir}/stats.json")
    markers = file("${params.identify_dir}/markers.faa")
    cluster_file = file("${params.identify_dir}/cluster_id_map.txt")
    cdhit_table = file("${params.identify_dir}/cdhit.tab")
    seqid_source_map = file("${params.identify_dir}/seqid_source_map.txt")
    db_dir = file(params.metagenome_db_dir)
    ags_normalization_file = file("${params.metagenome_db_dir}/AvgGenomeSize.txt")

    metagenome_ids_ch = Channel.from(params.metagenome_ids)
    metagenome_files = metagenome_ids_ch
        .map { id ->
            def filePath = file("${params.metagenome_db_dir}/${id}.fasta")
            return tuple(id, filePath)
        }

    results = cgfp_quantify(metagenome_files, markers)

    median_results_ch       = results.results_median.collect()
    median_results          = merge_median_raw(median_results_ch, cluster_file, ags_normalization_file, "", "")
    median_norm_results     = merge_median_norm(median_results_ch, cluster_file, ags_normalization_file, "_normalized", "normalized")
    median_ags_norm_results = merge_median_ags(median_results_ch, cluster_file, ags_normalization_file, "_genome_normalized", "ags_normalized")

    mean_results_ch         = results.results_mean.collect()
    mean_results            = merge_mean_raw(mean_results_ch, cluster_file, ags_normalization_file, "_mean", "")
    mean_norm_results       = merge_mean_norm(mean_results_ch, cluster_file, ags_normalization_file, "_normalized_mean", "normalized")
    mean_ags_norm_results   = merge_mean_ags(mean_results_ch, cluster_file, ags_normalization_file, "_genome_normalized_mean", "ags_normalized")

    create_quantify_ssn(ssn_file, median_ags_norm_results.protein, median_ags_norm_results.cluster, db_dir, seqid_source_map, cdhit_table)

    stats = compute_quantify_stats(median_results.protein)

    files_to_merge_stream = Channel.of(identify_stats).mix(stats)
    files_to_merge = files_to_merge_stream.collect()

    merge_stats(files_to_merge)
}

