
include { all_by_all_blast; blastreduce; blastreduce_transcode_fasta; condense_redundant; create_blast_db; restore_condensed; split_fasta } from "../../shared/nextflow/blast.nf"

workflow ALL_BY_ALL {
    take:
        original_fasta

    main:
        // Cluster redundant sequences for BLAST computation (formerly known as multiplex)
        if (params.multiplex) {
            condensed_files = condense_redundant(original_fasta)
            blast_input_fasta = condensed_files.fasta_file
            condensed = condensed_files.condensed
        } else {
            blast_input_fasta = original_fasta
            condensed = Channel.empty()
        }

        // Create BLAST database
        blastdb = create_blast_db(blast_input_fasta)

        // For stats computation later
        fasta_lengths_parquet = blastreduce_transcode_fasta(original_fasta)

        // All-by-all BLAST
        fasta_shards = split_fasta(blast_input_fasta)

        blast_input = blastdb.combine(fasta_shards.transpose(), by: 0)
        blast_fractions = all_by_all_blast( blast_input ).groupTuple()

        // Eliminate duplicate and self-edges
        reduced_blast_parquet = blastreduce(blast_fractions.join(fasta_lengths_parquet))

        // Expand redundant sequences after BLAST computation (formerly known as demultiplex)
        if (params.multiplex) {
            reduced_blast_parquet = restore_condensed(reduced_blast_parquet.join(condensed))
        }

    emit:
        fasta_lengths_parquet = fasta_lengths_parquet
        blast_parquet = reduced_blast_parquet
}

