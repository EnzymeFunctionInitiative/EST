
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
        path 'master_ids.tab', emit: 'master_ids'               // list of all primary IDs in the dataset
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
        --master-ids-file master_ids.tab \
        --stats-file import_stats.json \
        ${filter_args} ${user_filter_arg} \
        ${xids_file}
    """
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

def get_import_args() {
    def common_args = "--efi-config ${params.efi_config} --efi-db ${params.efi_db} --mode ${params.import_mode} --sequence-version ${params.sequence_version}"

    def family_args = ""
    if (params.families) {
        family_args = "--family \"${params.families}\""
    }

    if (params.domain) {
        family_args = "${family_args} --domain \"${params.domain_region}\""
        if (params.domain_family) {
            family_args = "${family_args} --domain-family \"${params.domain_family}\""
        }
    }

    return "${common_args} ${family_args}".trim()
}

workflow GET_SOURCE_IDS {
    main:
        def seq_mapping_ch = Channel.empty()   // Used by fasta option
        def input_file_ch = Channel.empty() // Return input file as a Nextflow channel
        def import_files = null

        if (params.import_mode == "accessions") {
            input_file_ch = Channel.fromPath(params.input_file)
            import_files = get_source_ids_accession(input_file_ch)
            seq_mapping_ch = Channel.empty()

        } else if (params.import_mode == "blast") {
            input_file_ch = Channel.fromPath(params.input_file)
            import_files = get_source_ids_blast(input_file_ch)
            seq_mapping_ch = Channel.empty()

        } else if (params.import_mode == "family") {
            import_files = get_source_ids_family()
            seq_mapping_ch = Channel.empty()

        } else if (params.import_mode == "fasta") {
            input_file_ch = Channel.fromPath(params.input_file)
            import_files = get_source_ids_fasta(input_file_ch)
            seq_mapping_ch = import_files.seq_mapping

        } else {
            seq_mapping_ch = Channel.empty()
            error "Mode '${params.import_mode}' not yet implemented"
        }

    emit:
        source_ids = import_files.source_ids
        source_meta = import_files.source_meta
        source_stats = import_files.source_stats
        input_file = input_file_ch
        seq_mapping = seq_mapping_ch
}

process get_source_ids_accession {
    input:
        path input_file
    output:
        path 'source_ids.tab', emit: 'source_ids'
        path 'source_seq.tab', emit: 'source_meta'
        path 'source_stats.json', emit: 'source_stats'
    script:

    def common_args = get_import_args()

    """
    perl $projectDir/../shared/import/get_sequence_ids.pl \
        ${common_args} \
        --accessions ${input_file}
    """
}

process get_source_ids_blast {
    label 'TASK_import_BLAST'
    memory { params.sequence_version == "uniprot" ? params.uniprot_db_size : { params.sequence_version == "uniref90" ? params.uniref90_db_size : params.uniref50_db_size } }
    def nCPUs = { task.memory.toGiga() / params.memory_cpu_ratio }
    cpus { nCPUs ? nCPUs.toInteger() + 1 : 1 }

    publishDir params.final_output_dir, mode: 'copy', pattern: '{blast_hits.tab}'
    input:
        path input_file
    output:
        path 'source_ids.tab', emit: 'source_ids'
        path 'source_seq.tab', emit: 'source_meta'
        path 'source_stats.json', emit: 'source_stats'
        path 'blast_hits.tab'
    script:

    def common_args = get_import_args()

    // blast_hits.tab is provided as an output to the user
    """
    blastall \
        -p blastp \
        -i ${input_file} \
        -d ${params.import_blast_fasta_db} \
        -m 8 \
        -e "${params.import_blast_evalue}" \
        -b "${params.import_blast_num_matches}" \
        -a ${task.cpus} \
        -o init_blast.out
    if [[ -s init_blast.out ]]; then
        awk '! /^#/ {print \$2"\t"\$11}' init_blast.out | sort -k2nr > blast_hits.tab
    else
        echo "BLAST did not return any matches.  Verify that the sequence is a protein and not a nucleotide sequence."
        exit 1
    fi
    perl $projectDir/../shared/import/get_sequence_ids.pl \
        ${common_args} \
        --blast-output init_blast.out \
        --blast-query ${input_file}
    """
}

process get_source_ids_family {
    output:
        path 'source_ids.tab', emit: 'source_ids'
        path 'source_seq.tab', emit: 'source_meta'
        path 'source_stats.json', emit: 'source_stats'
    script:

    def common_args = get_import_args()

    """
    perl $projectDir/../shared/import/get_sequence_ids.pl ${common_args}
    """
}

process get_source_ids_fasta {
    input:
        path input_file
    output:
        path 'source_ids.tab', emit: 'source_ids'
        path 'source_seq.tab', emit: 'source_meta'
        path 'source_stats.json', emit: 'source_stats'
        path 'seq_mapping.tab', emit: 'seq_mapping'
    script:

    def common_args = get_import_args()

    """
    perl $projectDir/../shared/import/get_sequence_ids.pl \
        ${common_args} \
        --fasta ${input_file} \
        --sequence-mapping-file seq_mapping.tab
    """
}

