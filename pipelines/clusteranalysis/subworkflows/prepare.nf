
process subset_fasta {
    tag "ca_sample_${id}"

    input:
        tuple val(type), val(id), path(fasta), val(sequence_type), val(num_seq)

    output:
        // We emit the same tuple structure so it can mix back easily later
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
        // We emit the same tuple structure so it can mix back easily later, and add the number
        // of sequences in the input file to the tuple
        tuple val(type), val(id), path(fasta), val(sequence_type), env(COUNT)

    script:

    """
    COUNT=\$(grep -c "^>" ${fasta})
    """
}

process cdhit_reduce {
    label 'APP_cd_hit'
    tag "ca_cdhit_${id}"

    input:
        tuple val(type), val(id), path(fasta), val(sequence_type)

    output:
        // We emit the same tuple structure so it can mix back easily later
        tuple val(type), val(id), path("*_cdhit.fasta"), val(sequence_type)

    script:

    """
    # Using legacy parameters: -c 1 -s 1 -M 14900
    # ^^^ not using the -M memory setting
    cd-hit -c 1 -s 1 \
           -i ${fasta} \
           -o ${id}_cdhit.fasta \
           -M ${task.memory.toMega()} \
           -T ${task.cpus}
    """
}

workflow PREPARE_FASTA {
    take:
        color_fasta_files
        sequence_type

    main:

        //
        // STEP 1: COLLECT ALL SEQUENCES INTO ONE CHANNEL
        //

        // The input color_fasta_files is a tuple (type, file) that contains the sequence type
        // (uniprot vs unirefXX) and file path.  Add a cluster ID item and SSN sequence type to
        // the tuple so we can associate the cluster ID with a file.  The result is the following
        // tuple:
        //     (type, cluster ID, file, sequence_type)
        color_fasta_ch = color_fasta_files
            .filter { file_type, file -> file.size() > 0 }
            .filter { file_type, file -> !file.name.contains("_All.fasta") }     // Don't include the file with all sequences in the analysis
            .filter { file_type, file -> !file.name.contains("singleton") }      // Don't include singletons in the analysis
            .map { file_type, file ->
                // Transform the file name into a cluster ID.  Removes "cluster_UniProt_" (or
                // "cluster_UniRefXX_") from the front if present
                def clean_id = file.simpleName.replaceAll(/^cluster_Uni(Prot|Ref90|Ref50)_(Domain_)?/, '')
                return tuple(file_type, clean_id, file)
            }
            .combine(sequence_type) // Add sequence type to the end of each tuple to allow a later step to limit files to the input SSN type

        // Obtain a channel only containing the files that will be passed to CD-HIT in the next
        // step.  Since color_fasta_ch contains all file types (UniProt, UniRef, domain, etc.),
        // compare the sequence file_type to the original SSN sequence type.  This branch code
        // stores only the files corresponding to the input SSN sequence type.  These get stored
        // in seq_type_fasta_ch.sequence_type_files.  If the input sequence_type is domain (e.g.
        // ending in '_domain'), then we also want to include the base type (e.g. uniref90 and
        // uniref90_domain).
        color_fasta_ch.branch {
            sequence_type_files:    it[0].replace('_domain', '') == it[3].replace('_domain', '')
            ignored_files:          true
        }.set { seq_type_fasta_ch }

        //
        // STEP 2: APPLY CD-HIT TO REDUCE REDUNDANCY
        //

        // Only apply CD-HIT to UniProt sequences
        seq_type_fasta_ch.sequence_type_files.branch {
            needs_reduction:    it[0].contains('uniprot')
            skip_reduction:     true
        }.set { reduction_set_ch }

        // Reduce all UniProt sequences by removing all sequences that are 100% identical over 100%
        // of the length of the sequence.  Then mix them with the sequences that did not need
        // reduction.
        condensed_ch = cdhit_reduce(reduction_set_ch.needs_reduction)
            .mix(reduction_set_ch.skip_reduction)

        //
        // STEP 3: SAMPLE THE FASTA TO REDUCE SIZE FOR MUSCLE
        //

        // Count the number of fasta sequences in each file
        counted_ch = count_fasta(condensed_ch)

        // Split channel into a branch that needs sampling, and one that doesn't
        counted_ch.branch {
            // Needs sampling (e.g. subsetting): if max_msa_sequences is set AND file exceeds it
            large: params.max_msa_sequences > 0 && it[4].toInteger() > params.max_msa_sequences
            // These don't need sampling
            small: params.min_msa_sequences == 0 || it[4].toInteger() >= params.min_msa_sequences
            // Exclude any files that are outside of the min/max range (e.g. small clusters)
            ignored: true
        }.set { split_sampled_ch }

//        split_sampled_ch.ignored.view { "Dropping cluster ${it[1]} because it's small to compute an MSA for" }

        // Sample the FASTA files (aka subsetting)
        sampled_ch = subset_fasta(split_sampled_ch.large)

        // Merge the 'small' files (not needing sampling) with the resampled files
        analysis_fasta_ch = sampled_ch.mix(split_sampled_ch.small)

    emit:
        // This will be for length histograms because we generate length histograms for *every*
        // sequence type
        color_fasta = color_fasta_ch

        // This will be used for MSA, etc, and includes the sequence type but only sequences in the
        // input SSN (e.g. uniref)
        analysis_fasta = analysis_fasta_ch
}
