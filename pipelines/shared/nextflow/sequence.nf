
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

process multiplex {
    input:
        path fasta_file
    output:
        path "sequences.fasta", emit: "fasta_file"
        path "sequences.fasta.clstr", emit: "clusters"
    """
    cd-hit -d 0  -c 1 -s 1 -i $fasta_file -o sequences.fasta -M 10000
    """
}

