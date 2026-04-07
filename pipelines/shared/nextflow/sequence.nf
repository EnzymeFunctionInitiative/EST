
process get_sequences {
    input:
        path accession_ids
        val fasta_db
    output:
        path "${accession_ids}.fasta"
    """
    if [[ -s "${accession_ids}" ]]; then
        perl $projectDir/../shared/perl/get_sequences.pl --fasta-db ${fasta_db} --sequence-ids-file ${accession_ids} --output-sequence-file ${accession_ids}.fasta
    else
        touch ${accession_ids}.fasta
    fi
    """
}

process get_length_histogram {
    input:
        path fasta_file
        path accession_table
        val seq_version
    output:
        path("*.histogram.txt"), emit: histograms
    """
    python $projectDir/../shared/python/compute_length_histogram.py --fasta-file $fasta_file --accession-table $accession_table --seq-type $seq_version  --output-file ${seq_version}.histogram.txt
    """
}

