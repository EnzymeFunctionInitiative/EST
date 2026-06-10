
include { filter_ids; get_sequences; GET_SOURCE_IDS; get_user_filter_file } from "../../shared/nextflow/sequence.nf"

process get_sunburst_data {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path accession_table
        path sequence_metadata
    output:
        path 'sunburst_tax.json'
    script:
    """
    perl $projectDir/../shared/import/get_sunburst_data.pl --efi-config ${params.efi_config} --efi-db ${params.efi_db}
    """
}

process cat_fasta_files {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path fasta_files
        path input_file
    output:
        path 'all_sequences.fasta'
    script:
    cat_cmd = "cat ${fasta_files} > all_sequences.fasta"
    if (params.import_mode == "blast") {
        """
        $cat_cmd
        perl $projectDir/import/append_blast_query.pl --blast-query-file ${input_file} --output-sequence-file all_sequences.fasta

        # Stop Nextflow here if the file is empty (i.e. no sequences were found)
        [ -s all_sequences.fasta ] || { echo "ERROR: No sequences found after retrieval and merge."; exit 1; }
        """
    } else {
        """
        $cat_cmd

        # Stop Nextflow here if the file is empty (i.e. no sequences were found)
        [ -s all_sequences.fasta ] || { echo "ERROR: No sequences found after retrieval and merge."; exit 1; }
        """
    }
}

process split_sequence_ids {
    input:
        path accessions_file
        val num_accession_shards
    output:
        path "accession_ids.txt.part*"
    """
    if [[ -s "${accessions_file}" ]]; then
        split -d -e -n r/$num_accession_shards ${accessions_file} accession_ids.txt.part
    else
        touch accession_ids.txt.part
    fi
    """
}

process import_fasta {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path sequence_metadata
        path seq_mapping
        path input_file
    output:
        path "imported_sequences.fasta", emit: "fasta_file"
    """
    perl $projectDir/import/import_fasta.pl --uploaded-fasta ${input_file} --sequence-mapping-file ${seq_mapping} --output-sequence-file imported_sequences.fasta
    """
}

workflow IMPORT_AND_FILTER {
    main:
        // We get sequence IDs and basic metadata from the input source, including those in FASTA files
        source_data = GET_SOURCE_IDS()

        user_filter_file = get_user_filter_file()

        // Filter on all sequence IDs including UniRef, and including IDs in FASTA files
        sequence_id_files = filter_ids(source_data.source_ids, source_data.source_meta, source_data.source_stats, Channel.value([]), user_filter_file)

        // Get sunburst data for all sequence IDs, after filtering
        get_sunburst_data(sequence_id_files.accession_table, sequence_id_files.sequence_metadata)

        // Split up the sequence ID list into separate files to enable parallel sequence retrieval
        // from the BLAST sequence database.  If the import mode is FASTA, then these IDs are only
        // ones that come from adding a family to the job
        accession_shards = split_sequence_ids(sequence_id_files.retrieval_ids, params.num_accession_shards)
        raw_fasta_files = get_sequences(accession_shards.flatten(), params.fasta_db)

        // If importing FASTA file, reformat the FASTA file and create the file that will be added to
        // the dataset for all-by-all BLAST
        if (params.import_mode == "fasta") {
            // sequence metadata is used to ensure that any sequences that were filtered out in a
            // prior step are also removed when rewriting the user fasta
            import_fasta_file = import_fasta(sequence_id_files.sequence_metadata, source_data.seq_mapping, source_data.input_file)
            fasta_files = raw_fasta_files.concat(import_fasta_file)
        } else {
            fasta_files = raw_fasta_files
        }

        all_fasta_files = fasta_files.collect()
        fasta_file = cat_fasta_files(
            all_fasta_files
                .ifEmpty { error "No FASTA sequences were retrieved. Terminating pipeline." },
            source_data.input_file.ifEmpty([])
        )

    emit:
        accession_table = sequence_id_files.accession_table
        fasta_file
        import_stats = sequence_id_files.import_stats
        sequence_metadata = sequence_id_files.sequence_metadata
}

