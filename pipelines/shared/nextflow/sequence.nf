
process split_sequence_ids {
    input:
        path accessions_file
        val num_accession_shards
    output:
        path "accession_ids.txt.part*"
    """
    if [[ -s "${accessions_file}" ]]; then
        split -d -e -n r/$num_accession_shards ${accessions_file} accession_ids.txt.part
    else
        touch accession_ids.txt.part
    fi
    """
}

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

// Formerly known as multiplex
process cluster {
    input:
        path fasta_file
    output:
        path "sequences.fasta", emit: "fasta_file"
        path "sequences.fasta.clstr", emit: "clusters"
    """
    cd-hit -d 0  -c 1 -s 1 -i ${fasta_file} -o sequences.fasta -M 10000
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

