
include { COMPUTE_COLOR_CLUSTER_WORKFLOW; get_cluster_stats } from "../shared/nextflow/color_workflow.nf"
include { get_sequences } from "../shared/nextflow/sequence.nf"
include { merge_stats; prepareJobName; prepareSsnFilename; unzip_ssn } from "../shared/nextflow/util.nf"
include { condense_redundant } from "../shared/nextflow/blast.nf"

process get_fasta_id_list {
    input:
        path cluster_id_map
        path metanode_map
        path singleton_list
    output:
        path "id_list.txt"

    script:
    """
    perl $projectDir/prep/get_id_list.pl --cluster-map ${cluster_id_map} --seqid-source-map ${metanode_map} --singletons ${singleton_list} --id-list id_list.txt
    """
}

process create_marker_ssn {
    publishDir params.final_output_dir, mode: "copy", pattern: "{marker_ssn.xgmml.zip,marker_ssn.xgmml,stats.json}"

    input:
        path ssn_file
        path marker_file
        path metanode_map
        path cdhit_table
    output:
        path "marker_ssn.xgmml.zip", emit: "marker_ssn_zip"
        path "marker_ssn.xgmml", emit: "marker_ssn"

    script:
    def default_name = "ShortBRED Markers"
    def final_job_name = prepareJobName(default_name)
    def file_name = prepareSsnFilename(default_name)
    def temp_name = "marker_ssn.xgmml"
    """
    perl $projectDir/create/create_identify_ssn.pl \
        --input ${ssn_file} \
        --output ${temp_name} \
        --marker-file ${marker_file} \
        --seqid-source-map ${metanode_map} \
        --cdhit-table ${cdhit_table} \
        --title "${final_job_name}"
    cp ${temp_name} "${file_name}"
    zip marker_ssn.xgmml.zip "${file_name}"
    rm "${file_name}"
    """
}

process cgfp_identify {
    publishDir params.final_output_dir, mode: "copy", pattern: "{markers.faa}"

    input:
        path fasta_file
        val ref_db /* Path to a BLAST database, DIAMOND database, or FASTA file */
    output:
        path "markers.faa", emit: "marker_file"
        path "clust.faa.clstr", emit: "cdhit"
        path "identify_stats.json", emit: "stats"

    script:
    def cdhit_sid       = params.sb_cdhit_sid   ? "--clustid ${params.sb_cdhit_sid}"                        : ""
    def cons_thresh     = params.sb_cons_thresh ? "--consthresh ${params.sb_cons_thresh}"                   : ""
    def diamond_sens    = ""
    def search_program  = ""
    def sb_src          = ""
    if (params.sb_identify_method == "diamond") {
        diamond_sens    = params.sb_diamond_sensitivity ? "--diamond-sensitivity ${params.sb_diamond_sensitivity}" : ""
        search_program  = "--search_program diamond"
        sb_src          = "shortbred_diamond"
    } else if (params.sb_identify_method) {
        sb_src          = "shortbred_blast"
    }

    """
    SB_TEMP_DIR=id-temp
    mkdir \$SB_TEMP_DIR

    python $projectDir/shortbred/${sb_src}/shortbred_identify.py \
        --threads ${params.sb_identify_threads} \
        --goi ${fasta_file} \
        --refdb ${ref_db} \
        --markers markers.faa \
        --tmp \$SB_TEMP_DIR \
        --muscle muscle3 \
        --usearch usearch \
        ${search_program} \
        ${diamond_sens} \
        ${cdhit_sid} \
        ${cons_thresh}

    cp \$SB_TEMP_DIR/clust/clust.faa.clstr clust.faa.clstr
#    rm -rf \$SB_TEMP_DIR

    perl $projectDir/prep/make_identify_stats.pl \
        --condensed-fasta ${fasta_file} \
        --markers markers.faa \
        --cdhit-file clust.faa.clstr \
        --stats identify_stats.json
    """
}

process get_merged_fasta_file {
    input:
        path ssn_seq_file
        path fasta_file
    output:
        tuple val("F"), path("merged.fasta")

    script:
    // Sequences in the first file are kept, while sequences in the second file with the same
    // ID are discarded; otherwise the sequences from fasta_file are merged
    """
    seqkit rmdup \
        -i ${ssn_seq_file} ${fasta_file} \
        -o merged.fasta
    """
}

process create_cdhit_table {
    publishDir params.final_output_dir, mode: "copy", pattern: "{cdhit.tab}"

    input:
        path cdhit_file
        path cluster_id_map
    output:
        path "cdhit.tab"

    script:
    """
    perl $projectDir/prep/make_cdhit_table.pl \
        --cdhit-file ${cdhit_file} \
        --cluster-map ${cluster_id_map} \
        --table-file cdhit.tab
    """
}

workflow {
    if (params.ssn_input =~ /\.zip$/) {
        ssn_file = unzip_ssn(Channel.value(file(params.ssn_input)))
    } else {
        ssn_file = Channel.value(file(params.ssn_input))
    }

    // Compute the clusters
    color_work = COMPUTE_COLOR_CLUSTER_WORKFLOW(ssn_file)

    // Get the FASTA based on the sequence IDs
    fasta_id_list_file = get_fasta_id_list(color_work.cluster_id_map, color_work.seqid_source_map, color_work.singletons)
    id_fasta_file = get_sequences(fasta_id_list_file, params.fasta_db)

    // Get the sequences that are defined in the SSN, then merge the sequences defined in the
    // SSN with the ones retrieved from the ID list. Overwrite any in the ID list FASTA with
    // the SSN FASTA.
    ssn_fasta_file = get_merged_fasta_file(color_work.ssn_sequences, id_fasta_file)

    condensed_out = condense_redundant(ssn_fasta_file)
    condensed_fasta = condensed_out.fasta_file.map { id, file -> file }

    results = cgfp_identify(condensed_fasta, params.sb_search_refdb)

    cdhit_table = create_cdhit_table(results.cdhit, color_work.cluster_id_map)

    marker_ssn_data = create_marker_ssn(ssn_file, results.marker_file, color_work.seqid_source_map, cdhit_table)

    ssn_stats = get_cluster_stats(color_work.cluster_id_map, color_work.seqid_source_map, color_work.singletons)

    files_to_merge_stream = ssn_stats.mix(results.stats)
    files_to_merge = files_to_merge_stream.collect()

    merge_stats(files_to_merge)
}

