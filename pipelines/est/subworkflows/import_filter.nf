
process get_source_ids {
    publishDir params.final_output_dir, mode: 'copy'
    output:
        path 'source_ids.tab', emit: 'source_ids'
        path 'source_seq.tab', emit: 'source_meta'
        path 'source_stats.json', emit: 'source_stats'
        path 'blast_hits.tab', optional: true // only used in blast mode
        path 'seq_mapping.tab', emit: 'sequence_mapping', optional: true // only used in fasta mode
        path 'unmatched_id.tab', optional: true // only used in fasta or accessions mode
    script:

    common_args = "--efi-config ${params.efi_config} --efi-db ${params.efi_db} --mode ${params.import_mode} --sequence-version ${params.sequence_version}"

    family_args = ""
    if (params.families) {
        family_args = "--family " + params.families
    }

    if (params.domain) {
        family_args = family_args + " --domain " + params.domain
        if (params.domain_family) {
            family_args = family_args + " --domain-family " + params.domain_family
        }
    }

    if (params.import_mode == "blast") {
        // blast_hits.tab is provided as an output to the user
        """
        blastall -p blastp -i ${params.blast_query_file} -d ${params.import_blast_fasta_db} -m 8 -e ${params.import_blast_evalue} -b ${params.import_blast_num_matches} -o init_blast.out
        if [[ -s init_blast.out ]]; then
            awk '! /^#/ {print \$2"\t"\$11}' init_blast.out | sort -k2nr > blast_hits.tab
        else
            echo "BLAST did not return any matches.  Verify that the sequence is a protein and not a nucleotide sequence."
            exit 1
        fi
        perl $projectDir/import/get_sequence_ids.pl $common_args $family_args --blast-output init_blast.out --blast-query ${params.blast_query_file}
        """
    } else if (params.import_mode == "accessions") {
        """
        perl $projectDir/import/get_sequence_ids.pl $common_args $family_args --accessions ${params.accessions_file}
        """
    } else if (params.import_mode == "fasta") {
        """
        perl $projectDir/import/get_sequence_ids.pl $common_args $family_args --fasta ${params.uploaded_fasta_file} --seq-mapping-file seq_mapping.tab
        """
    } else if (params.import_mode == "family") {
        """
        perl $projectDir/import/get_sequence_ids.pl $common_args $family_args
        """
    } else {
        error "Mode '${params.import_mode}' not yet implemented"
    }
}

process filter_ids {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path source_ids     // table of all sequence IDs, including UniRef IDs
        path source_meta    // sequence metdata
        path source_stats   // statistics of source import process
    output:
        path 'accession_table.tab', emit: 'accession_table'     // table of all sequence IDs, including UniRef IDs, filtered
        path 'sequence_metadata.tab', emit: 'sequence_metadata' // sequence metdata in metadata format
        path 'import_stats.json', emit: 'import_stats'          // final statistics of source and filter import processes
        path 'retrieval_ids.tab', emit: 'retrieval_ids'         // list of IDs that came from the database, as opposed to user-specified FASTA files, including domain data
    script:
    filter_args = ""
    if (params.filter) {
        filter_args = params.filter.join(" --filter ")
        filter_args = "--filter ${filter_args}"
    }
    """
    perl $projectDir/import/filter_ids.pl --efi-config ${params.efi_config} --efi-db ${params.efi_db} --sequence-version ${params.sequence_version} $filter_args
    """
}

process get_sunburst_data {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path accession_table
        path sequence_metadata
    output:
        path 'sunburst_tax.json'
    script:
    """
    perl $projectDir/import/get_sunburst_data.pl --efi-config ${params.efi_config} --efi-db ${params.efi_db} \
        --sequence-meta-file $sequence_metadata --accession-table-file $accession_table \
        --sunburst-data-file sunburst_tax.json
    """
}

workflow IMPORT_AND_FILTER {
    main:
        // We get sequence IDs and basic metadata from the input source, including those in FASTA files
        source_data = get_source_ids()
    
        // Filter on all sequence IDs including UniRef, and including IDs in FASTA files
        sequence_id_files = filter_ids(source_data.source_ids, source_data.source_meta, source_data.source_stats)
    
        // Get sunburst data for all sequence IDs, after filtering
        get_sunburst_data(sequence_id_files.accession_table, sequence_id_files.sequence_metadata)

    emit:
        accession_table = sequence_id_files.accession_table
        import_stats = sequence_id_files.import_stats
        retrieval_ids = sequence_id_files.retrieval_ids
        sequence_mapping = source_data.sequence_mapping
        sequence_metadata = sequence_id_files.sequence_metadata
}

