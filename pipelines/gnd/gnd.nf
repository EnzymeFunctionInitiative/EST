
process create_gnd {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path id_list 
        path blast_evalue_file
    output:
        path "gnd.sqlite", emit: "gnd_db"
        path "gnd.sqlite.zip", emit: "zipped_gnd_db"
        path "stats.json", emit: "stats"

    script:
    def blastHitsArgs = params.import_mode == "blast" ? "--blast-evalues ${blast_evalue_file}" : ""
    
    // If there was no job name specified, then assign a default
    def final_job_name = params.job_name ?: "${params.import_mode}, Sequence Source: ${params.sequence_version}, nNeighbors: ${params.nb_size}"

    """
    perl ${projectDir}/create_gnd.pl \
        --efi-config "${params.efi_config}" \
        --efi-db "${params.efi_db}" \
        --sequence-version ${params.sequence_version} \
        --cluster-map ${id_list} \
        --nb-size ${params.nb_size} \
        --gnd gnd.sqlite \
        --stats stats.json \
        --title "${final_job_name}" \
        ${blastHitsArgs}
    zip gnd.sqlite.zip gnd.sqlite
    """
}

process run_blast {
    input:
        path sequence_file
    output:
        path "init_blast.out", emit: "raw_blast_out"
        path "blast_hits.tab", emit: "e_values"

    script:
    """
    blastall -p blastp \
        -i ${sequence_file} \
        -d "${params.import_blast_fasta_db}" \
        -b ${params.import_blast_num_matches} \
        -e ${params.import_blast_evalue} \
        -m 8 \
        -o init_blast.out

    if [[ -s init_blast.out ]]; then
        awk '! /^#/ {print \$2"\t"\$11}' init_blast.out | sort -k2nr > blast_hits.tab
    else
        echo "BLAST did not return any matches.  Verify that the sequence is a protein and not a nucleotide sequence." | tee /dev/stderr
        exit 1
    fi
    """
}

process parse_blast_results_for_ids {
    input:
        path sequence_file
        path blast_file
    output:
        path "accession_ids.tab", emit: "source_ids"
        path "sequence_meta.tab", emit: "source_meta"

    script:
    """
    perl $projectDir/../shared/import/get_sequence_ids.pl \
        --efi-config "${params.efi_config}" \
        --efi-db "${params.efi_db}" \
        --sequence-version ${params.sequence_version} \
        --mode blast \
        --blast-output ${blast_file} \
        --blast-query ${sequence_file} \
        --source-meta-file sequence_meta.tab \
        --source-ids-file accession_ids.tab
    """
}

process parse_fasta_for_ids {
    input:
        path fasta_file
    output:
        path "accession_ids.tab", emit: "source_ids"
        path "sequence_meta.tab", emit: "source_meta"

    script:
    """
    perl $projectDir/../shared/import/get_sequence_ids.pl \
        --efi-config "${params.efi_config}" \
        --efi-db "${params.efi_db}" \
        --sequence-version ${params.sequence_version} \
        --mode fasta \
        --fasta ${fasta_file} \
        --source-meta-file sequence_meta.tab \
        --source-ids-file accession_ids.tab
    """
}

process parse_accession_for_ids {
    input:
        path accession_file
    output:
        path "accession_ids.tab", emit: "source_ids"
        path "sequence_meta.tab", emit: "source_meta"

    script:
    """
    perl $projectDir/../shared/import/get_sequence_ids.pl \
        --efi-config "${params.efi_config}" \
        --efi-db "${params.efi_db}" \
        --sequence-version ${params.sequence_version} \
        --mode accessions \
        --accessions ${accession_file} \
        --source-meta-file sequence_meta.tab \
        --source-ids-file accession_ids.tab
    """
}

process convert_to_id_list {
    input:
        path source_ids
        path source_meta
    output:
        path "cluster_id_mapping.tab", emit: id_list

    script:
    """
    perl $projectDir/convert_metadata_to_id_list.pl \
        --cluster-id-mapping cluster_id_mapping.tab \
        --source-ids-file "${source_ids}" \
        --source-meta-file "${source_meta}"
    """
}

workflow {
    def input_file_ch = Channel.fromPath(params.input_file)

    if (params.import_mode == "accessions") {
        parse_data = parse_accession_for_ids(input_file_ch)
        extra_metadata_file = Channel.value([])
    } else if (params.import_mode == "blast") {
        blast_results = run_blast(input_file_ch)
        parse_data = parse_blast_results_for_ids(input_file_ch, blast_results.raw_blast_out)
        extra_metadata_file = blast_results.e_values
    } else if (params.import_mode == "fasta") {
        parse_data = parse_fasta_for_ids(input_file_ch)
        extra_metadata_file = Channel.value([])
        //extra_metadata_file = Channel.empty()
    } else {
        error "Mode '${params.import_mode}' is invalid"
    }

    id_list = convert_to_id_list(parse_data.source_ids, parse_data.source_meta)

    gnd = create_gnd(id_list, extra_metadata_file)
}

