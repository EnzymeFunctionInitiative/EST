
include { REPORTING } from "./subworkflows/reporting.nf"
include { ALL_BY_ALL } from "./subworkflows/all_by_all.nf"
include { IMPORT_AND_FILTER } from "./subworkflows/import.nf"

workflow {

    initial_data = IMPORT_AND_FILTER()

    axa_results = ALL_BY_ALL(initial_data.fasta_file)

    results = REPORTING(axa_results.blast_parquet, axa_results.fasta_lengths_parquet, initial_data.fasta_file, initial_data.accession_table, initial_data.import_stats)
}

