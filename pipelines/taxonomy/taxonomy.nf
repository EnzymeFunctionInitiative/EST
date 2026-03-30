
include { get_source_ids; filter_ids; get_sunburst_data } from "../est/subworkflows/import.nf"
include { merge_stats } from "../shared/nextflow/util.nf"

workflow {

        // We get sequence IDs and basic metadata from the input source, including those in FASTA files
        source_data = get_source_ids()

        // Filter on all sequence IDs including UniRef, and including IDs in FASTA files
        sequence_id_files = filter_ids(source_data.source_ids, source_data.source_meta, source_data.source_stats)

        // Get sunburst data for all sequence IDs, after filtering
        get_sunburst_data(sequence_id_files.accession_table, sequence_id_files.sequence_metadata)
        
        // Create the stats.json file
        final_stats = merge_stats(sequence_id_files.import_stats)

    emit:
        final_stats
}

