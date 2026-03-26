
include { get_sequences; split_sequence_ids } from "../../shared/nextflow/sequence.nf"

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
        family_args = "--family " + params.families
    }

    if (params.domain) {
        family_args = family_args + " --domain " + params.domain_region
        if (params.domain_family) {
            family_args = family_args + " --domain-family " + params.domain_family
        }
    }

    if (params.import_mode == "blast") {
        // blast_hits.tab is provided as an output to the user
        """
        blastall -p blastp -i ${params.input_file} -d ${params.import_blast_fasta_db} -m 8 -e ${params.import_blast_evalue} -b ${params.import_blast_num_matches} -o init_blast.out
        if [[ -s init_blast.out ]]; then
            awk '! /^#/ {print \$2"\t"\$11}' init_blast.out | sort -k2nr > blast_hits.tab
        else
            echo "BLAST did not return any matches.  Verify that the sequence is a protein and not a nucleotide sequence."
            exit 1
        fi
        perl $projectDir/../shared/perl/get_sequence_ids.pl $common_args $family_args --blast-output init_blast.out --blast-query ${params.input_file}
        """
    } else if (params.import_mode == "accessions") {
        """
        perl $projectDir/../shared/perl/get_sequence_ids.pl $common_args $family_args --accessions ${params.input_file}
        """
    } else if (params.import_mode == "fasta") {
        """
        perl $projectDir/../shared/perl/get_sequence_ids.pl $common_args $family_args --fasta ${params.input_file} --sequence-mapping-file seq_mapping.tab
        """
    } else if (params.import_mode == "family") {
        """
        perl $projectDir/../shared/perl/get_sequence_ids.pl $common_args $family_args
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
    perl $projectDir/../est/import/filter_ids.pl --efi-config ${params.efi_config} --efi-db ${params.efi_db} --sequence-version ${params.sequence_version} $filter_args
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
    perl $projectDir/../est/import/get_sunburst_data.pl --efi-config ${params.efi_config} --efi-db ${params.efi_db}
    """
}

process cat_fasta_files {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path '*.fasta'
    output:
        path 'all_sequences.fasta'
    script:
    cat_cmd = "cat *.fasta > all_sequences.fasta"
    if (params.import_mode == "blast") {
        """
        $cat_cmd
        perl $projectDir/import/append_blast_query.pl --blast-query-file ${params.input_file} --output-sequence-file all_sequences.fasta
        """
    } else {
        cat_cmd
    }
}

process import_fasta {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path sequence_metadata
        path seq_mapping
    output:
        path "imported_sequences.fasta", emit: "fasta_file"
    """
    perl $projectDir/import/import_fasta.pl --uploaded-fasta ${params.input_file} --sequence-mapping-file ${seq_mapping} --output-sequence-file imported_sequences.fasta
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

        // Split up the sequence ID list into separate files to enable parallel sequence retrieval
        // from the BLAST sequence database.  If the import mode is FASTA, then these IDs are only
        // ones that come from adding a family to the job
        accession_shards = split_sequence_ids(sequence_id_files.retrieval_ids, params.num_accession_shards)
        fasta_files = get_sequences(accession_shards.flatten(), params.fasta_db)

        // If importing FASTA file, reformat the FASTA file and create the file that will be added to
        // the dataset for all-by-all BLAST
        if (params.import_mode == "fasta") {
            // sequence metadata is used to ensure that any sequences that were filtered out in a
            // prior step are also removed when rewriting the user fasta
            import_fasta_file = import_fasta(sequence_id_files.sequence_metadata, source_data.seq_mapping)
            fasta_files = fasta_files.concat(import_fasta_file)
        }

        fasta_file = cat_fasta_files(fasta_files.collect())

    emit:
        accession_table = sequence_id_files.accession_table
        fasta_file
        import_stats = sequence_id_files.import_stats
}

