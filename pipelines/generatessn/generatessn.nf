
include { filter_ids } from "../shared/nextflow/sequence.nf"

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
    output:
        path "2.out"
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
        --sql-output-file thresholded_blast.sql
    duckdb < thresholded_blast.sql
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
    publishDir params.final_output_dir, mode: 'copy', pattern: "*.{zip,json,finish}"
    input:
        path thresholded_blast
        path all_fasta
        path ssn_meta_file
    output:
        path "full_ssn.xgmml.zip", emit: "ssn"
        path "ssn.xgmml", emit: "ssn_unzipped"
        path "job.finish"
        path "stats.json", emit: "stats"

    // If there was no job name specified, then assign a default
    def final_job_name = params.job_name ?: "Full SSN"

    // Create a clean job name for the file
    def clean_file_name = final_job_name
        .replaceAll(/[^\p{ASCII}]/, "")
        .replaceAll(/[^a-zA-Z0-9_\-\.]/, "_")
        .replaceAll(/^[_-]+|[_-]+$/, "")
        .toLowerCase();

    def file_name = (clean_file_name ?: "full_ssn") + ".xgmml"

    """
    perl $projectDir/create/create_full_ssn.pl \
        --blast ${thresholded_blast} \
        --fasta ${all_fasta} \
        --metadata ${ssn_meta_file} \
        --output ssn.xgmml \
        --title "${final_job_name}" \
        --db-version ${params.db_version} \
        --stats stats.json
    cp ssn.xgmml "${file_name}"
    zip full_ssn.xgmml.zip "${file_name}"
    rm "${file_name}"
    touch job.finish
    """
}

workflow {
    // Import data from EST run
    input_data = import_data(params.blast_parquet, params.fasta_file, params.source_ids_file, params.seq_meta_file)

    // Apply threshold to BLAST and fasta file
    thresholded_blast = threshold_blast(input_data.blast_output)

    // Explicitly specify the IDs that will be passed through, by computing the lengths of the
    // sequences and returning a file containing IDs for all of the sequences that fit the length
    // criteria.
    def explicit_ids_file = (params.min_length != 0 || params.max_length != 65000)
        ? compute_fasta_lengths(input_data.fasta)
        : Channel.value([])

    // Filter sequences out by length or other criteria (e.g. fragment, taxonomy)
    final_ids = filter_ids(input_data.source_ids, input_data.seq_meta_file, input_data.stats, explicit_ids_file)

    // Get annotations
    ssn_meta_file = get_annotations(final_ids.sequence_metadata)

    // Create networks
    full_ssn = create_full_ssn(thresholded_blast, input_data.fasta, ssn_meta_file)
}
