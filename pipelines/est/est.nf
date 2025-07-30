
include { get_sequences; split_sequence_ids } from "../shared/nextflow/sequence.nf"
include { IMPORT_AND_FILTER } from "./subworkflows/import_filter.nf"
include { BLAST_AXA } from "./subworkflows/blast_axa.nf"
include { REPORTING } from "./subworkflows/reporting.nf"
include { cat_fasta_files; import_fasta } from "./subworkflows/fasta_proc.nf"

workflow {

    // Step 1: Find sequence ids using params

    initial_data = IMPORT_AND_FILTER()

    // Step 2: Retrieve sequences

    // Split up the sequence ID list into separate files to enable parallel sequence retrieval
    // from the BLAST sequence database.  If the import mode is FASTA, then these IDs are only
    // ones that come from adding a family to the job
    accession_shards = split_sequence_ids(initial_data.retrieval_ids, params.num_accession_shards)
    fasta_files = get_sequences(accession_shards.flatten(), params.fasta_db)

    if (params.import_mode == "fasta") {
        import_fasta_file = import_fasta(initial_data.sequence_metadata, initial_data.sequence_mapping)
        fasta_files = fasta_files.concat(import_fasta_file)
    }

    fasta_file = cat_fasta_files(fasta_files.collect())

    // Step 3: Perform all-by-all blast computation on the sequences

    axa_files = BLAST_AXA(fasta_file)

    // Step 4: Compute statistics, output stats files (JSON), and visualizations and viz data

    reporting = REPORTING(axa_files.blast_parquet, axa_files.fasta_lengths_parquet, fasta_file, initial_data.accession_table, initial_data.import_stats)
}

