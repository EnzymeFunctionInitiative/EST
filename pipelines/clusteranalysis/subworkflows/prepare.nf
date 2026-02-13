
process subset_fasta {
    tag "ca_sample_${id}"

    input:
        tuple val(type), val(id), path(fasta)

    output:
        tuple val(type), val(id), path("*_subset.fasta")

    script:

    """
wget https://github.com/shenwei356/seqkit/releases/download/v2.8.2/seqkit_linux_amd64.tar.gz
    tar -xvf seqkit_linux_amd64.tar.gz
    # --two-pass dramatically reduces memory usage for large files
    # -s 100 sets a fixed seed for reproducibility
    ./seqkit sample --two-pass -n ${params.max_msa_sequences} -s 100 ${fasta} > ${id}_subset.fasta
    """
}

process cdhit_reduce {
    tag "ca_cdhit_${id}"

    input:
        tuple val(type), val(id), path(fasta)

    output:
        // We emit the same triplet structure so it can mix back easily later
        tuple val(type), val(id), path("*_cdhit.fasta")

    script:

    """
    # Using legacy parameters: -c 1 -s 1 -M 14900
    cd-hit -c 1 -s 1 -i ${fasta} -o ${id}_cdhit.fasta -M 14900
    """
}

workflow prepare_fasta {
    take:
        color_fasta_files

    main:

        // STEP 1: COLLECT ALL SEQUENCES INTO ONE CHANNEL

        // Add 'type' column to tuple
        color_fasta_ch = color_fasta_files
            .filter { type, file -> !file.name.contains("_All.fasta") }     // Don't include the file with all sequences in the analysis
            .filter { type, file -> !file.name.contains("singleton") }      // Don't include singletons in the analysis
            .map { type, file ->
                // Extract the filename without extension (e.g. "cluster_UniProt_Cluster_1")
                def raw_id = file.simpleName 
                // Clean up the ID to be just the cluster number
                // This regex removes "cluster_UniProt_" from the front if present
                def clean_id = raw_id.replaceAll(/^cluster_Uni(Prot|Ref90|Ref50)_/, '')
                return tuple(type, clean_id, file)
            }

        // STEP 2: APPLY CD-HIT TO REDUCE REDUNDANCY

        // Split channel into branches, one needing CD-HIT and the other to pass through
        color_fasta_ch.branch {
            to_cdhit: it[0] == 'uniprot'
            to_msa:   true
        }.set { split_fasta_ch }

        // Reduce all sequences that are uniprot
        cdhit_results = cdhit_reduce(split_fasta_ch.to_cdhit)

        // Merge split channels
        reduction_ch = split_fasta_ch.to_msa.mix(cdhit_results)

        // STEP 3: SAMPLE THE FASTA TO REDUCE SIZE FOR MUSCLE

        // Split channel into a branch that needs sampling, and one that doesn't
        reduction_ch.branch {
            // Needs subsetting (Too big)
            // Check if max_msa_sequences is set AND file exceeds it
            large: params.max_msa_sequences > 0 && it[2].countFasta() > params.max_msa_sequences
            // Don't need to subset
            small: params.min_msa_sequences == 0 || it[2].countFasta() >= params.min_msa_sequences
            // Exclude any files that are outside of the min/max range
            ignored: true
        }.set { split_sampled_ch }

        split_sampled_ch.ignored.view { "Dropping cluster ${it[1]} because it's small to compute an MSA for" }

        // Sample the FASTA files (aka subsetting)
        sampled_ch = subset_fasta(split_sampled_ch.large)

        // Merge the 'small' files (not needing sampling) with the resampled files
        analysis_fasta_ch = sampled_ch.mix(split_sampled_ch.small)

    emit:
        analysis_fasta_ch
}
