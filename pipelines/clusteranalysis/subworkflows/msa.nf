
process muscle5_align {
    tag "ca_muscle5_${id}"

    publishDir "${params.final_output_dir}/data/msa", mode: "copy", pattern: "*.afa"

    input:
        tuple val(id), path(fasta)

    output:
        tuple val(id), path("*.afa"), emit: msa

    script:
    """
    NUM_SEQS=\$(grep -c ">" ${fasta})
    if [ "\$NUM_SEQS" -gt 50 ]; then
        MODE_ARG="-super5"
    else
        MODE_ARG="-align"
    fi
    muscle5 \$MODE_ARG ${fasta} -output ${id}.afa -threads ${task.cpus}
    """
}

process muscle3_align {
    tag "ca_muscle3_${id}"

    publishDir "${params.final_output_dir}/data/msa", mode: "copy", pattern: "*.afa"

    // MUSCLE can crash due to out of memory errors, or invalid data.  If we crash due to OOM,
    // retry twice with larger amounts of RAM.  Otherwise, ignore the failure and proceed with
    // the other clusters.
    memory { 2.GB * task.attempt }
    maxRetries 2
    errorStrategy {
        // 137 == OOM, 140 == timeout
        task.exitStatus in [137, 140] ? 'retry' : 'ignore'
    }

    input:
        tuple val(id), path(fasta)

    output:
        tuple val(id), path("*.afa"), emit: msa

    script:
    """
    muscle3 -in ${fasta} -out ${id}.afa
    """
}

process build_hmms {
    tag "ca_hmms_${id}"

    publishDir "${params.final_output_dir}/data/hmms", mode: "copy", pattern: "*.hmm"
    publishDir "${params.final_output_dir}/data/hmms", mode: "copy", pattern: "*.json"

    input:
        tuple val(id), path(msa)

    output:
        path("*.hmm")
        path("*.json")

    script:
    """
    hmmbuild ${id}.hmm ${msa}
    python ${projectDir}/logo/convert_hmm_to_skylign_json.py --hmm ${id}.hmm --json ${id}.json
    """
}

process make_weblogos {
    tag "ca_weblogos_${id}"

    publishDir "${params.final_output_dir}/data/weblogos", mode: "copy", pattern: "*.png"

    input:
        tuple val(id), path(msa)

    output:
        path("*.png"), emit: pngs
        path("*.txt"), emit: logos

    script:
    """
    weblogo -D fasta -F png --resolution 300 --stacks-per-line 80 -f ${msa} -o ${id}.png
    weblogo -D fasta -F logodata -f ${msa} -o ${id}.txt
    """
}

process run_clustal_omega {
    tag "ca_clustal_${id}"

    // Ignore any clustal computations because we don't want a failure to block the pipeline.
    // This output isn't crucial.
    errorStrategy 'ignore'

    input:
        tuple val(id), path(msa)

    output:
        tuple path("*_pim.txt")

    script:
    """
    clustalo -i ${msa} --percent-id --distmat-out=${id}_pim.txt --full --force
    """
}

process zip_clustal_omega {
    tag "ca_clustal_zip"
    
    publishDir params.final_output_dir, mode: "copy", pattern: "*.zip"

    input:
        tuple path(clustal_pims)

    output:
        path("*.zip")

    script:
    """
    if [ -n "${clustal_pims}" ]; then
        dir="clustal_pims"
        mkdir \$dir
        cp *.txt \$dir
        zip -jr "clustal_pims.zip" \$dir
        rm -rf \$dir
    fi
    """
}

process count_msa_aa {
    tag "ca_count_msa_aa"

    publishDir "${params.final_output_dir}/data/cons_res/consensus_residue_results_${aa}", mode: "copy", pattern: "*.txt"

    input:
        path "msa_files/*"
        path "logo_files/*"
        path cluster_count_file
        path id_cluster_mapping
        tuple val(aa), val(threshold)

    output:
        tuple val(aa), val(threshold), path("consensus_residue_${threshold}_position.txt"), path("consensus_residue_${threshold}_percentage.txt")

    script:
    def base_name = "consensus_residue_${threshold}"
    """
    perl $projectDir/conv_ratio/count_msa_aa.pl --msa-dir msa_files --logo-dir logo_files --aa ${aa} --count-file ${base_name}_position.txt --pct-file ${base_name}_percentage.txt --threshold ${threshold} --node-count-file ${cluster_count_file}
    mkdir id_lists_${threshold}
    perl $projectDir/conv_ratio/collect_aa_ids.pl --aa-count-file ${base_name}_position.txt --output-dir id_lists_${threshold} --id-mapping ${id_cluster_mapping}
    """
}

process summarize_msa_aa {
    tag "ca_summarize_msa_aa"

    publishDir "${params.final_output_dir}/data/cons_res", mode: "copy", pattern: "*.txt"

    input:
        tuple val(aa), path(pos_files), path(pct_files)

    output:
        path("*.txt")

    script:
    def base_name = "ConsensusResidue_${aa}"
    """
    perl $projectDir/conv_ratio/make_summary_tables.pl --position-summary-file ${base_name}_Position_Summary_Full.txt --percentage-summary-file ${base_name}_Percentage_Summary_Full.txt --position-files ${pos_files} --percentage-files ${pct_files}
    """
}

workflow align_and_analyze {
    take:
        prepared_fasta_ch
        id_cluster_mapping

    main:
        // Compute the cluster size file
        cluster_size_file = prepared_fasta_ch
            .map { type, id, fasta, seq_type, num_seq -> "${id}\t${num_seq}\n" }
            .collectFile(
                name: "cluster_size.txt",
                storeDir: params.final_output_dir,
                keepHeader: false
            )

        analysis_fasta_ch = prepared_fasta_ch.map { type, id, fasta, seq_type, num_seq -> tuple(id, fasta) }

        // Perform alignment using MUSCLE
        if (params.muscle_version == 3) {
            msa_ch = muscle3_align(analysis_fasta_ch)
        } else {
            msa_ch = muscle5_align(analysis_fasta_ch)
        }

        // Create HMMs
        build_hmms(msa_ch)

        // Create weblogo graphics and logo data file
        weblogo_ch = make_weblogos(msa_ch)
        logos_ch = weblogo_ch.logos.collect()

        // Compute consensus residues
        residue_ch = Channel.from(params.conserved_residues)    // Allow Nextflow to run count_msa_aa simultaneously
        threshold_ch = Channel.from(params.pid_thresholds)      // Allow Nextflow to run count_msa_aa simultaneously
        msa_files_ch = msa_ch.map { it[1] }.collect()
        counted_residues_ch = count_msa_aa(msa_files_ch, logos_ch, cluster_size_file, id_cluster_mapping, residue_ch.combine(threshold_ch))

        // groupTuple allows us to create a structure that looks like [AA, [pos_files, ...], [pct_files, ...]]
        residues_ch = counted_residues_ch
            .map { aa, threshold, pos_file, pct_file -> tuple(aa, pos_file, pct_file) }
            .groupTuple()
        summarize_msa_aa(residues_ch)

        // Compute percent ID matrices using Clustal-Omega
        // groupTuple allows us to create a structure that looks like [uniprot, [files, ...]]
        clustal_ch = run_clustal_omega(msa_ch)
            .groupTuple()
        zip_clustal_omega(clustal_ch)

        if (params.pid_thresholds && !params.pid_thresholds.isEmpty()) {
            clustal_inputs = msa_ch.combine(Channel.fromList(params.pid_thresholds))
        }
}
