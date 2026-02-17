
process subset_fasta {
    tag "ca_sample_${id}"

    input:
        tuple val(type), val(id), path(fasta), val(sequence_type), val(num_seq)

    output:
        tuple val(type), val(id), path("*_subset.fasta"), val(sequence_type), val(num_seq)

    script:

    """
    # --two-pass dramatically reduces memory usage for large files
    # -s 100 sets a fixed seed for reproducibility
    seqkit sample --two-pass -n ${params.max_msa_sequences} -s 100 ${fasta} > ${id}_subset.fasta
    """
}

process count_fasta {
    tag "ca_count_fasta_${id}"

    input:
        tuple val(type), val(id), path(fasta), val(sequence_type)

    output:
        tuple val(type), val(id), path(fasta), val(sequence_type), env(COUNT)

    script:

    """
    COUNT=\$(grep -c "^>" ${fasta})
    """
}

process cdhit_reduce {
    tag "ca_cdhit_${id}"

    input:
        tuple val(type), val(id), path(fasta), val(sequence_type)

    output:
        // We emit the same triplet structure so it can mix back easily later
        tuple val(type), val(id), path("*_cdhit.fasta"), val(sequence_type)

    script:

    """
    # Using legacy parameters: -c 1 -s 1 -M 14900
    cd-hit -c 1 -s 1 -i ${fasta} -o ${id}_cdhit.fasta -M 14900
    """
}

workflow prepare_fasta {
    take:
        color_fasta_files
        sequence_type

    main:

        // STEP 1: COLLECT ALL SEQUENCES INTO ONE CHANNEL

        // Add cluster ID column to tuple
        color_fasta_ch = color_fasta_files
            .filter { file_type, file -> !file.name.contains("_All.fasta") }     // Don't include the file with all sequences in the analysis
            .filter { file_type, file -> !file.name.contains("singleton") }      // Don't include singletons in the analysis
            .map { file_type, file ->
                // Extract the filename without extension (e.g. "cluster_UniProt_Cluster_1")
                def raw_id = file.simpleName 
                // Clean up the ID to be just the cluster number
                // This regex removes "cluster_UniProt_" from the front if present
                def clean_id = raw_id.replaceAll(/^cluster_Uni(Prot|Ref90|Ref50)_/, '')
                return tuple(file_type, clean_id, file)
            }
            .combine(sequence_type)

        // Only use the files for the sequence file_type that was provided (e.g. if the input
        // is UniRef50 SSN, then only use UniRef50 sequences)
        color_fasta_ch.branch {
            sequence_type_files:    it[0] == it[3]
            ignored_files:          true
        }.set { seq_type_fasta_ch }

        // STEP 2: APPLY CD-HIT TO REDUCE REDUNDANCY

        seq_type_fasta_ch.sequence_type_files.branch {
            needs_reduction:    it[0] == 'uniprot'
            skip_reduction:     true
        }.set { reduction_set_ch }

        // Reduce all sequences that are uniprot by removing all sequences that are 100% identical over 100% of the length of the sequence
        condensed_ch = cdhit_reduce(reduction_set_ch.needs_reduction)
            .mix(reduction_set_ch.skip_reduction)

        // STEP 3: SAMPLE THE FASTA TO REDUCE SIZE FOR MUSCLE

        // Count the number of fasta sequences in each file
        counted_ch = count_fasta(condensed_ch)

        // Split channel into a branch that needs sampling, and one that doesn't
        counted_ch.branch {
            // Needs subsetting (Too big)
            // Check if max_msa_sequences is set AND file exceeds it
            large: params.max_msa_sequences > 0 && it[4].toInteger() > params.max_msa_sequences
            // Don't need to subset
            small: params.min_msa_sequences == 0 || it[4].toInteger() >= params.min_msa_sequences
            // Exclude any files that are outside of the min/max range
            ignored: true
        }.set { split_sampled_ch }

        split_sampled_ch.ignored.view { "Dropping cluster ${it[1]} because it's small to compute an MSA for" }

        // Sample the FASTA files (aka subsetting)
        sampled_ch = subset_fasta(split_sampled_ch.large)

        // Merge the 'small' files (not needing sampling) with the resampled files
        analysis_fasta_ch = sampled_ch.mix(split_sampled_ch.small)

    emit:
        // This will be for length histograms because we generate length histograms for every sequence type
        color_fasta = color_fasta_ch
        // This will be used for MSA, etc, and include the sequence type but only sequences in the input SSN (e.g. uniref)
        analysis_fasta = analysis_fasta_ch
}
