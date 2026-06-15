
include { all_by_all_blast; blastreduce; blastreduce_transcode_fasta; condense_redundant; create_blast_db; restore_condensed; remove_self_alignments; sort_and_split_fasta } from "../../shared/nextflow/blast.nf"

workflow ALL_BY_ALL {
    take:
        original_fasta

    main:
        // For stats computation later; using the original fasta file
        fasta_lengths_parquet = blastreduce_transcode_fasta(original_fasta)

        // Cluster redundant sequences for BLAST computation (formerly known as multiplex).
        // Only performed when input sequences are from Uniprot, since sequence sets from
        // UniRef90 and UniRef50 are already sequence-unique.
        if (params.multiplex && params.sequence_version == "uniprot") {
            condensed_files = condense_redundant(original_fasta)
            blast_input_fasta = condensed_files.fasta_file
            condensed = condensed_files.condensed
        } else {
            blast_input_fasta = original_fasta
            condensed = Channel.empty()
        }

        // Create BLAST database
        blastdb = create_blast_db(blast_input_fasta)

        // All-by-all BLAST
        fasta_shards = sort_and_split_fasta(blast_input_fasta)

        blast_input = blastdb.combine(fasta_shards.transpose(), by: 0)
        blast_fractions = all_by_all_blast( blast_input ).groupTuple()

        // Eliminate duplicates
        top_triangle_parquet = blastreduce(blast_fractions.join(fasta_lengths_parquet))

        // Expand redundant sequences after BLAST computation (formerly known as demultiplex)
        if (params.multiplex && params.sequence_version == "uniprot") {
            reduced_blast_parquet = restore_condensed(top_triangle_parquet.join(condensed))
        }
        else {
            reduced_blast_parquet = remove_self_alignments(top_triangle_parquet)
        }

    emit:
        fasta_lengths_parquet = fasta_lengths_parquet
        blast_parquet = reduced_blast_parquet
}

