
include { COMPUTE_COLOR_CLUSTER_WORKFLOW } from "../shared/nextflow/color_workflow.nf"
include { color_ssn } from "../shared/nextflow/color_xgmml.nf"
include { filter_ids } from "../shared/nextflow/sequence.nf"
include { merge_stats; zip_files } from "../shared/nextflow/util.nf"

def getCleanFilename(job_name, default_name) {
    // Create a clean job name for the file
    def clean_file_name = job_name
        .replaceAll(/[^\p{ASCII}]/, "")
        .replaceAll(/[^a-zA-Z0-9_\-\.]/, "_")
        .replaceAll(/^[_-]+|[_-]+$/, "");
    def file_name = (clean_file_name ?: default_name) + ".xgmml"
    return file_name
}

process import_data {
    input:
        path existing_blast_output
        path existing_fasta_file
        path existing_accession_table
        path existing_seq_meta_file
    output:
        path '_1.out.parquet', emit: blast_output
        path '_sequences.fa', emit: fasta
        path '_accession_table.tab', emit: source_ids
        path '_sequence_metadata.tab', emit: seq_meta_file
        path 'empty_stats.json', emit: stats                // This serves as an empty placeholder; required as a starting point for filter_ids

    script:
    """
    cp $existing_blast_output _1.out.parquet
    cp $existing_fasta_file _sequences.fa
    cp $existing_accession_table _accession_table.tab
    cp $existing_seq_meta_file _sequence_metadata.tab
    echo "{}" > empty_stats.json
    """
}

process threshold_blast {
    input:
        path blast_parquet
        path filtered_ids
    output:
        path "2.out"

    script:
    """
    DUCKDB_TEMP="${params.duckdb_temp_dir}/duckdb-${task.index}-"\$(date +%s)
    python $projectDir/threshold/render_threshold_blast_sql_template.py \
        --blast-output $blast_parquet \
        --threshold-metric ${params.threshold_metric} \
        --threshold-min-val ${params.threshold_min_val} \
        --min-length ${params.min_length} \
        --max-length ${params.max_length} \
        --sql-template $projectDir/templates/thresholdblast-template.sql \
        --duckdb-memory-limit ${params.duckdb_memory_limit} \
        --duckdb-temp-dir \${DUCKDB_TEMP} \
        --output-file 2.out \
        --sql-output-file thresholded_blast.sql \
        --filtered-ids-file ${filtered_ids}
    duckdb < thresholded_blast.sql
    """
}

process filter_fasta {
    input:
        path input_fasta
        path filtered_ids
    output:
        path "filtered_sequences.fasta"

    script:
    """
    seqkit grep -f ${filtered_ids} ${input_fasta} -o filtered_sequences.fasta
    """
}

process compute_fasta_lengths {
    input:
        path fasta_file
    output:
        path "explicit_id_list.tab"

    script:
    def min_len_arg = params.min_length != 0 ? "--min-len ${params.min_length}" : ""
    def max_len_arg = params.max_length != 65000 ? "--max-len ${params.max_length}" : ""
    """
    seqkit seq ${min_len_arg} ${max_len_arg} --name --only-id --remove-gaps ${fasta_file} > ids.tab
    # Remove domain information from the IDs
    sed 's/:[^\t]*//' ids.tab > explicit_id_list.tab
    """
}

process get_annotations {
    input:
        path filtered_seq_meta_file
    output:
        path "ssn_metadata.tab"

    script:
    """
    perl $projectDir/annotations/get_annotations.pl \
        --ssn-anno-out ssn_metadata.tab \
        --min-len ${params.min_length} \
        --max-len ${params.max_length} \
        --seq-meta-in $filtered_seq_meta_file \
        --config ${params.efi_config} \
        --db-name ${params.efi_db}
    """
}

process create_full_ssn {
    publishDir params.final_output_dir, mode: 'copy', pattern: "*.{zip}"

    input:
        path blast
        path all_fasta
        path ssn_meta_file
        path nc_table // Optional (can be empty)
    output:
        path "full_ssn.xgmml.zip", emit: "ssn"
        path "full_ssn.xgmml", emit: "ssn_unzipped"
        path "full_stats.json", emit: "stats"

    script:
    // If there was no job name specified, then assign a default
    def default_name = "Full SSN"
    def final_job_name = params.job_name ?: default_name
    def file_name = getCleanFilename(final_job_name, default_name)
    def temp_name = "full_ssn.xgmml"

    """
    NC_ARG=""
    if [ -n "${nc_table}" ] && [ -f "${nc_table}" ]; then
        NC_ARG="--nc-map ${nc_table}"
    fi

    perl $projectDir/create/create_full_ssn.pl \
        --blast ${blast} \
        --fasta ${all_fasta} \
        --metadata ${ssn_meta_file} \
        --output ${temp_name} \
        --title "${final_job_name}" \
        --max-edges ${params.max_ssn_edges} \
        --db-version ${params.db_version} \
        \$NC_ARG \
        --stats-ssn-name "full_ssn.xgmml.zip" \
        --stats full_stats.json
    cp ${temp_name} "${file_name}"
    zip full_ssn.xgmml.zip "${file_name}"
    rm "${file_name}"
    """
}

process create_repnode_ssns {
    publishDir params.final_output_dir, mode: 'copy', pattern: "*.{zip}"

    input:
        path blast
        path all_fasta
        path ssn_meta_file
        tuple val(repnode_pct), path(repnode_cdhit), path(nc_table)
    output:
        path "repnode_${repnode_pct}_ssn.xgmml.zip", emit: "ssn"
        path "repnode_${repnode_pct}_stats.json", emit: "stats"

    script:
    // If there was no job name specified, then assign a default
    def default_name = "repnode-${repnode_pct}"
    def final_job_name = params.job_name ? params.job_name + " " + default_name : default_name
    def file_name = getCleanFilename(final_job_name, default_name)
    def temp_name = "repnode_${repnode_pct}_ssn.xgmml"

    """
    NC_ARG=""
    if [ -n "${nc_table}" ] && [ -f "${nc_table}" ]; then
        NC_ARG="--nc-map ${nc_table}"
    fi

    perl $projectDir/create/create_repnode_ssn.pl \
        --blast ${blast} \
        --fasta ${all_fasta} \
        --metadata ${ssn_meta_file} \
        --cdhit ${repnode_cdhit} \
        --output "${temp_name}" \
        --title "${final_job_name}" \
        --db-version ${params.db_version} \
        \$NC_ARG \
        --stats repnode_${repnode_pct}_stats.json
    mv "${temp_name}" "${file_name}"
    zip "${temp_name}.zip" "${file_name}"
    rm "${file_name}"
    """
}

process compute_repnode_cdhit {
    input:
        path all_fasta
        val repnode_pct
    output:
        tuple val(repnode_pct), path("cdhit_${repnode_pct}.clstr")

    script:
    def cdhit_pct = (repnode_pct.toBigDecimal() / 100).setScale(2, BigDecimal.ROUND_HALF_UP)

    // This is left over from the legacy code, and is being kept here for future work (e.g. CGFP)
    def word_opt = 2
    def algo_opt = "" // "-g 1"
    def bandwidth_opt = "" // optional user input, in future
    def length_overlap_opt = "-s 1" // optional user input, in future

    // For future modes
    //if (cdhit_pct < 0.51)      { word_opt = 2 }
    //else if (cdhit_pct < 0.61) { word_opt = 3 }
    //else if (cdhit_pct < 0.71) { word_opt = 4 }
    //else { word_opt = 5 }

    """
    cd-hit -n ${word_opt} ${length_overlap_opt} -i ${all_fasta} -o cdhit_${repnode_pct} -c ${cdhit_pct} -d 0 ${algo_opt} ${bandwidth_opt}
    """
}

process compute_full_connectivity_from_blast {
    publishDir params.final_output_dir, mode: "copy", pattern: "{full_nc.tab}"

    input:
        path blast_tsv
        path cdhit_clstr // Optional (if empty)
    output:
        path "full_nc.tab", emit: "nc_table"

    script:
    """
    CDHIT_ARG=""
    if [ -n "${cdhit_clstr}" ] && [ -f "${cdhit_clstr}" ]; then
        CDHIT_ARG="--cdhit ${cdhit_clstr}"
    fi

    python $projectDir/../shared/connectivity/get_connectivity.py \
        --input-blast ${blast_tsv} \
        \$CDHIT_ARG \
        --output-map full_nc.tab
    """
}

process compute_repnode_connectivity_from_blast {
    publishDir params.final_output_dir, mode: "copy", pattern: "{*.tab}"

    input:
        path blast_tsv
        tuple val(repnode_pct), path(cdhit_clstr)
    output:
        tuple val(repnode_pct), path("repnode_${repnode_pct}_nc.tab")

    script:
    """
    python $projectDir/../shared/connectivity/get_connectivity.py \
        --input-blast ${blast_tsv} \
        --cdhit ${cdhit_clstr} \
        --output-map "repnode_${repnode_pct}_nc.tab"
    """
}

process make_full_nc_legend {
    publishDir params.final_output_dir, mode: "copy", pattern: "{full_nc_legend.png}"

    input:
        path nc_table
    output:
        path "full_nc_legend.png", emit: "legend"

    script:
    """
    python $projectDir/../shared/connectivity/make_color_ramp.py \
        --input-file ${nc_table} \
        --output-file full_nc_legend.png
    """
}

process make_repnode_nc_legend {
    publishDir params.final_output_dir, mode: "copy", pattern: "{*.png}"

    input:
        tuple val(repnode_pct), path(nc_table)
    output:
        path "repnode_${repnode_pct}_nc_legend.png", emit: "legend"

    script:
    """
    python $projectDir/../shared/connectivity/make_color_ramp.py \
        --input-file ${nc_table} \
        --output-file "repnode_${repnode_pct}_nc_legend.png"
    """
}

workflow {
    // Import data from EST run
    input_data = import_data(params.blast_parquet, params.fasta_file, params.source_ids_file, params.seq_meta_file)

    // Explicitly specify the IDs that will be passed through, by computing the lengths of the
    // sequences and returning a file containing IDs for all of the sequences that fit the length
    // criteria.
    explicit_ids_file = (params.min_length != 0 || params.max_length != 65000)
        ? compute_fasta_lengths(input_data.fasta)
        : Channel.value([])

    // Filter sequences out by length or other criteria (e.g. fragment, taxonomy)
    final_ids = filter_ids(input_data.source_ids, input_data.seq_meta_file, input_data.stats, explicit_ids_file, Channel.value([]))

    filtered_fasta = filter_fasta(input_data.fasta, final_ids.retrieval_ids)

    // Apply threshold to BLAST file
    thresholded_blast = threshold_blast(input_data.blast_output, final_ids.retrieval_ids)

    // Get annotations
    ssn_meta_file = get_annotations(final_ids.sequence_metadata)

    if (params.compute_ssn_nc_factor) {
        full_nc_table = compute_full_connectivity_from_blast(thresholded_blast, Channel.value([]))
        make_full_nc_legend(full_nc_table)
    } else {
        full_nc_table = Channel.value([])
    }

    // Create full network
    full_ssn = create_full_ssn(thresholded_blast, filtered_fasta, ssn_meta_file, full_nc_table)

    // Create repnode networks
    if (params.make_repnodes) {
        // Get a channel so we can parallelize the computations
        repnode_pct_ch = Channel.from(params.repnode_pct)

        // Compute the CD-HIT cluster files necessary for grouping nodes into repnodes
        cdhit_result = compute_repnode_cdhit(filtered_fasta, repnode_pct_ch)

        // Compute the neighborhood connectivity values
        if (params.compute_ssn_nc_factor) {
            nc_table = compute_repnode_connectivity_from_blast(thresholded_blast, cdhit_result)
            make_repnode_nc_legend(nc_table)
        } else {
            nc_table = repnode_pct_ch.map { pct -> [pct, []] }
        }

        // Create a tuple: [pct, cdhit_file, nc_table_file]
        create_repnode_inputs = cdhit_result.join(nc_table)

        repnode_ssns = create_repnode_ssns(thresholded_blast, filtered_fasta, ssn_meta_file, create_repnode_inputs)
        repnode_stats = repnode_ssns.stats
    } else {
        repnode_stats = Channel.of([])
    }

    // Merge full and repnode SSN stats into one file
    final_stats = merge_stats(full_ssn.stats.mix(repnode_stats).collect())

    if (params.color_ssn) {
        computed = COMPUTE_COLOR_CLUSTER_WORKFLOW(full_ssn.ssn_unzipped)
        colored_ssn = color_ssn(full_ssn.ssn_unzipped, computed.cluster_id_map, computed.cluster_num_map, computed.cluster_colors)
        zipped_full_ssn = zip_files(colored_ssn.ssn)
    }
}
