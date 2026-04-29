
def formatFilterArgs(filter_list) {
    if (!filter_list || filter_list.isEmpty()) {
        return ""
    }
    def filter_args_list = filter_list.findAll { !it.startsWith("user-filter=") }
    return !filter_args_list.isEmpty() ? "--filter " + filter_args_list.join(" --filter ") : ""
}

def get_user_filter_file() {
    def user_filter_entry = params.filter?.find { it.startsWith("user-filter=") }
    def user_filter_file = user_filter_entry ? file(user_filter_entry.split('=')[1]) : Channel.value([])
    return user_filter_file
}

process filter_ids {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path source_ids         // table of all sequence IDs, including UniRef IDs
        path source_meta        // sequence metdata
        path source_stats       // statistics of source import process
        path explicit_ids_file  // manually specify which IDs pass through; this may be empty (e.g. Channel.value([]))
        path user_filter_file   // path to user taxonomy filter file; this may be empty (e.g. Channel.value([]));
                                //     this is necessary to stage the filter file so it can be read inside this process
    output:
        path 'accession_table.tab', emit: 'accession_table'     // table of all sequence IDs, including UniRef IDs, filtered
        path 'sequence_metadata.tab', emit: 'sequence_metadata' // sequence metdata in metadata format
        path 'import_stats.json', emit: 'import_stats'          // final statistics of source and filter import processes
        path 'retrieval_ids.tab', emit: 'retrieval_ids'         // list of IDs that came from the database, as opposed to user-specified FASTA files, including domain data
    script:
    def xids_file = explicit_ids_file ? "--filter explicit-ids-file=${explicit_ids_file}" : ""
    def filter_args = formatFilterArgs(params.filter)
    def user_filter_arg = user_filter_file ? "--filter user-filter=${user_filter_file}" : ""
    """
    perl $projectDir/../shared/import/filter_ids.pl \
        --efi-config ${params.efi_config} \
        --efi-db ${params.efi_db} \
        --sequence-version ${params.sequence_version} \
        --source-ids-file ${source_ids} \
        --source-meta-file ${source_meta} \
        --source-stats-file ${source_stats} \
        --accession-table-file accession_table.tab \
        --sequence-meta-file sequence_metadata.tab \
        --retrieval-ids-file retrieval_ids.tab \
        --stats-file import_stats.json \
        ${filter_args} ${user_filter_arg} \
        ${xids_file}
    """
}

process get_source_ids {
    publishDir params.final_output_dir, mode: 'copy'
    output:
        path 'source_ids.tab', emit: 'source_ids'
        path 'source_seq.tab', emit: 'source_meta'
        path 'source_stats.json', emit: 'source_stats'
        path 'blast_hits.tab', optional: true
        path 'seq_mapping.tab', emit: 'seq_mapping', optional: true
        path 'unmatched_id.tab', optional: true
    script:

    common_args = "--efi-config ${params.efi_config} --efi-db ${params.efi_db} --mode ${params.import_mode} --sequence-version ${params.sequence_version}"

    family_args = ""
    if (params.families) {
        family_args = "--family \"${params.families}\""
    }

    if (params.domain) {
        family_args = "${family_args} --domain ${params.domain_region}"
        if (params.domain_family) {
            family_args = "${family_args} --domain-family ${params.domain_family}"
        }
    }

    if (params.import_mode == "blast") {
        // blast_hits.tab is provided as an output to the user
        """
        blastall \
            -p blastp \
            -i ${params.input_file} \
            -d ${params.import_blast_fasta_db} \
            -m 8 \
            -e "${params.import_blast_evalue}" \
            -b "${params.import_blast_num_matches}" \
            -o init_blast.out
        if [[ -s init_blast.out ]]; then
            awk '! /^#/ {print \$2"\t"\$11}' init_blast.out | sort -k2nr > blast_hits.tab
        else
            echo "BLAST did not return any matches.  Verify that the sequence is a protein and not a nucleotide sequence."
            exit 1
        fi
        perl $projectDir/../shared/import/get_sequence_ids.pl \
            ${common_args} \
            ${family_args} \
            --blast-output init_blast.out \
            --blast-query ${params.input_file}
        """
    } else if (params.import_mode == "accessions") {
        """
        perl $projectDir/../shared/import/get_sequence_ids.pl \
            ${common_args} \
            ${family_args} \
            --accessions ${params.input_file}
        """
    } else if (params.import_mode == "fasta") {
        """
        perl $projectDir/../shared/import/get_sequence_ids.pl \
            ${common_args} \
            ${family_args} \
            --fasta ${params.input_file} \
            --sequence-mapping-file seq_mapping.tab
        """
    } else if (params.import_mode == "family") {
        """
        perl $projectDir/../shared/import/get_sequence_ids.pl ${common_args} ${family_args}
        """
    } else {
        error "Mode '${params.import_mode}' not yet implemented"
    }
}

process get_sequences {
    input:
        path accession_ids
        val fasta_db
    output:
        path "${accession_ids}.fasta"
    """
    if [[ -s "${accession_ids}" ]]; then
        perl $projectDir/../shared/import/get_sequences.pl \
            --fasta-db ${fasta_db} \
            --sequence-ids-file ${accession_ids} \
            --output-sequence-file ${accession_ids}.fasta
    else
        touch ${accession_ids}.fasta
    fi
    """
}

process get_length_histogram {
    input:
        path fasta_file
        path accession_table
        val seq_version
    output:
        path("${seq_version}.histogram.txt"), emit: histograms
    """
    python $projectDir/../shared/python/compute_length_histogram.py \
        --fasta-file ${fasta_file} \
        --accession-table ${accession_table} \
        --seq-type ${seq_version} \
        --output-file ${seq_version}.histogram.txt
    """
}

