
include { REPORTING } from "./subworkflows/reporting.nf"
include { ALL_BY_ALL } from "./subworkflows/all_by_all.nf"
include { IMPORT_AND_FILTER } from "./subworkflows/import.nf"

workflow {

    initial_data = IMPORT_AND_FILTER()

    // Wrap the fasta file into a tuple.  This is because we share code with the convergence
    // ratio pipeline, which needs to run all of the processes in ALL_BY_ALL on many fasta
    // files, not just the one that we have here.
    blast_input = initial_data.fasta_file.map { fasta_file -> tuple("ALL_DATA", fasta_file) }
    axa_results = ALL_BY_ALL(blast_input)

    blast_parquet = axa_results.blast_parquet.map { fid, file -> file }
    fasta_lengths_parquet = axa_results.fasta_lengths_parquet.map { fid, file -> file }

    results = REPORTING(blast_parquet, fasta_lengths_parquet, initial_data.fasta_file, initial_data.accession_table, initial_data.import_stats)
}

