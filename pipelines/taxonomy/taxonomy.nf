
include { get_source_ids; filter_ids; get_sunburst_data } from "../est/subworkflows/import.nf"
include { merge_stats } from "../shared/nextflow/util.nf"

process process_sunburst_stats {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path sunburst_tax_file
        path import_stats_file
    output:
        path 'sunburst_stats.json', emit: 'stats_file'
    script:
    """
    python $projectDir/statistics/import_stats.py --sunburst-file ${sunburst_tax_file} --stats-file ${import_stats_file} --output sunburst_stats.json
    """
}

workflow {

        // We get sequence IDs and basic metadata from the input source, including those in FASTA files
        source_data = get_source_ids()

        // Filter on all sequence IDs including UniRef, and including IDs in FASTA files
        sequence_id_files = filter_ids(source_data.source_ids, source_data.source_meta, source_data.source_stats)

        // Get sunburst data for all sequence IDs, after filtering
        sunburst_file = get_sunburst_data(sequence_id_files.accession_table, sequence_id_files.sequence_metadata)
        
        // Process the sunburst file and import_stats.json files
        stats = process_sunburst_stats(sunburst_file, sequence_id_files.import_stats)

        // Create the stats.json file
        final_stats = merge_stats(stats.stats_file)

    emit:
        final_stats
}

