process get_cluster_count_fasta {
    output:
        path 'cluster_node_counts.txt'

    """
    perl $projectDir/clusteranalysis/get_cluster_count/get_cluster_count.pl --fasta-dir ${params.fasta_dir} --count-file cluster_node_counts.txt
    """
}

process get_cluster_count_size {
    output:
        path 'cluster_list_min_seq.txt'
    """
    perl $projectDir/clusteranalysis/get_cluster_count/get_cluster_count.pl --size-file ${params.size_file} --count-file cluster_list_min_seq.txt --min-count ${params.min_count}
    """
}

process msa {
    input:
        val min_seq
        path cluster_subset_fasta
    output:
        path "cluster_${min_seq}.afa", emit: "alignment_file"
        path "cluster_${min_seq}.txt", emit "weblogo_file"
    script:
    subset_fasta_file = "cluster_${min_seq}_subset${params.max_seq}.fasta"
    """
    perl $projectDir/clusteranalysis/msa/subset_fasta.pl --fasta-in ${params.cluster_dir}/fasta-${params.sequence_version}/cluster_${min_seq}.fasta --fasta-out $subset_fasta_file --max-seq ${params.max_seq}
    muscle -quiet -in $subset_fasta_file -fastaout cluster_${min_seq}.afa -clwstrictout cluster_${min_seq}.clw || true
    clustalo -i cluster_${min_seq}.clw --percent-id --distmat-out=cluster_${min_seq}_distmat.txt --full --force || true
    hmmbuild cluster_${min_seq}.hmm cluster_${min_seq}.afa
    perl $projectDir/clusteranalysis/msa/make_skylign_logo.pl --hmm cluster_${min_seq}.hmm --json cluster_${min_seq}.json --png cluster_${min_seq}_skylign.png
    
    /home/groups/efi/apps/bin/weblogo -D fasta -F png --resolution 300 --stacks-per-line 80 -f cluster_${min_seq}.afa -o cluster_${min_seq}_weblogo.png  --color red C 'C'
    /home/groups/efi/apps/bin/weblogo -D fasta -F logodata -f cluster_${min_seq}.afa -o cluster_${min_seq}.txt
    """
}

process consensus_residue_calculation {
    input:
        tuple val(search_amino_acid), val(threshold)
        path alignment_files //afa
        path weblogo_files
        path cluster_node_counts
    output:
        tuple val(search_amino_acid), val(threshold), path("consensus_residue_${threshold}_${search_amino_acid}_position.txt"), emit: 'count_file'
        tuple val(search_amino_acid), val(threshold), path("consensus_residue_${threshold}_${search_amino_acid}_percentage.txt"), emit: 'pct_file'
        path "count_*.txt", emit: 'count_files'
    """
    count_msa_aa.pl --msa-dir . --logo-dir . --aa $search_amino_acid --count-file consensus_residue_${threshold}_${search_amino_acid}_position.txt --pct-file consensus_residue_${threshold}_${search_amino_acid}_percentage.txt --threshold ${threshold} --node-count-file $cluster_node_counts
    collect_aa_ids.pl --aa-count-file consensus_residue_${threshold}_${search_amino_acid}_position.txt --output-dir . --id-mapping ${params.mapping_table}
    """
}

process summary_tables {
    input:
        tuple val(search_amino_acid), val(threshold_count), path(count_files), val(threshold_percentage), path(percentage_files)
    output:
        path "ConsensusResidue_${search_amino_acid}_Position_Summary_Full.txt"
        path "ConsensusResidue_${search_amino_acid}_Percentage_Summary_Full.txt"
    script:
    file_args = input.map({aa, tc, cf, tp, pf -> "--position-file $tc=$cf --percentage-file $pc=$pf"}).join(" ")
    """
    make_summary_tables.pl --position-summary-file ConsensusResidue_${search_amino_acid}_Position_Summary_Full.txt \
                           --percentage-summary-file ConsensusResidue_${search_amino_acid}_Percentage_Summary_Full.txt  \
                           $file_args
    """
}

process length_histograms {
    """
    perl make_length_histo.pl -seq-file ${params.cluster_dir}/fasta-${params.sequence_version}/cluster_${min_seq}.fasta -histo-file /private_stores/jobs/results/est/128715/output/cluster-data/hmm/full/normal/hist-uniprot/%.txt
    Rscript /home/groups/efi/apps/prod/GNT/hmm/hist-length.r legacy %.txt %.png 0 'Full-UniProt' 700 315

    make_length_histo.pl -seq-file /private_stores/jobs/results/est/128715/output/cluster-data/fasta-uniref90/%.fasta -histo-file /private_stores/jobs/results/est/128715/output/cluster-data/hmm/full/normal/hist-uniref90/%.txt
    Rscript /home/groups/efi/apps/prod/GNT/hmm/hist-length.r legacy %.txt %.png 0 'Full-uniref90' 700 315
    """
    make_length_histo.pl
    hist-length.r
}

workflow {
    cluster_node_counts = get_cluster_count_fasta()
    cluster_list_min_seq = Channel.fromPath(get_cluster_count_size())
    crc_combos = Channel.Combine(Channel.fromList(params.thresholds), Channel.fromList(params.search_amino_acids))

    msa_muscle(cluster_list_min_seq.splitText().flatten()).collect()

    crc_result = consensus_residue_calculation(crc_combos, msa_muscle.alignment_file, msa_muscle.weblogo_file, cluster_node_counts).collect()
    crc_groupby_aa_position = crc_result.count_file.groupTuple()
    crc_groupby_aa_percentage = crc_result.pct_file.groupTuple()
    crc_groupby_aa = Channel.join(crc_groupby_aa_position, crc_groupby_aa_percentage).transpose()

    summary_tables(crc_groupby_aa)
}