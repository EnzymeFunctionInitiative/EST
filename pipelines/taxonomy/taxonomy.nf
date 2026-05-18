
include { filter_ids; GET_SOURCE_IDS; get_user_filter_file; get_sequences } from "../shared/nextflow/sequence.nf"
include { create_blast_db } from "../shared/nextflow/blast.nf"
include { get_length_histogram; visualize_length_histograms } from "../shared/nextflow/reporting.nf"

process get_sunburst_data {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path accession_table
        path sequence_metadata
    output:
        path 'sunburst_tax.json', emit: 'taxon_file'
        path 'sunburst_stats.json', emit: 'stats_file'
    script:
    """
    perl $projectDir/../shared/import/get_sunburst_data.pl \
        --efi-config ${params.efi_config} \
        --efi-db ${params.efi_db} \
        --sunburst-stats-file sunburst_stats.json
    """
}

process process_sunburst_stats {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path sunburst_stats_file
        path import_stats_file
    output:
        path 'stats.json'
    script:
    """
    python $projectDir/statistics/update_import_stats.py \
        --stats-file ${sunburst_stats_file} \
        ${import_stats_file} \
        --output stats.json
    """
}

workflow {

    // We get sequence IDs and basic metadata from the input source, including those in FASTA files
    source_data = GET_SOURCE_IDS()

    user_filter_file = get_user_filter_file()

    // Filter on all sequence IDs including UniRef, and including IDs in FASTA files.
    // The last parameter is empty (used only for generatessn)
    sequence_id_files = filter_ids(source_data.source_ids, source_data.source_meta, source_data.source_stats, Channel.value([]), user_filter_file)

    // Get sunburst data for all sequence IDs, after filtering
    sunburst_data = get_sunburst_data(sequence_id_files.accession_table, sequence_id_files.sequence_metadata)

    // Process the sunburst_stats.json and import_stats.json files
    process_sunburst_stats(sunburst_data.stats_file, sequence_id_files.import_stats)

    // Get fasta file of UniProtKB-level sequences
    fasta_file = get_sequences(sequence_id_files.accession_table, params.fasta_db)

    // Plot the sequence lengths for UniProtKB, Uniref90, Uniref50
    seq_versions = ["uniprot", "uniref90", "uniref50"]
    seq_version_ch = Channel.fromList(seq_versions)

    length_histograms = get_length_histogram(fasta_file, sequence_id_files.accession_table, seq_version_ch)
    histo_viz = visualize_length_histograms(length_histograms)

    // Make Blast sequence database
    fasta_file_tuple = fasta_file.map { fasta_file -> tuple("ALL_DATA", fasta_file) }

    create_blast_db(fasta_file_tuple)

}

