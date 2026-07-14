
process muscle5_align {
    tag "ca_muscle5_${id}"
    label "muscle_align"
    publishDir "${params.final_output_dir}/data/msa/${seq_type}", mode: "copy", pattern: "*.afa"

    input:
        tuple val(id), path(fasta), val(seq_type)
    output:
        tuple val(id), path("${id}.afa"), val(seq_type), emit: msa

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
    label "muscle_align"
    publishDir "${params.final_output_dir}/data/msa/${seq_type}", mode: "copy", pattern: "*.afa"

    // MUSCLE can crash due to out of memory errors; it also might run for extended time
    // especially for large sequence sets. Set the max time this process block can run in
    // the config file. If a process runs beyond this time, a timeout error is thrown.
    // Ignore these failures, skip the cluster being analyzed, and proceed with
    // the other clusters. Any other errors should cause a terminate message to nextflow.
    errorStrategy {
        // 137 == OOM, 140 == timeout
        task.exitStatus in [137, 140] ? 'ignore' : 'terminate'
    }

    input:
        tuple val(id), path(fasta), val(seq_type)
    output:
        tuple val(id), path("${id}.afa"), val(seq_type), emit: msa

    script:
    """
    # -maxhours h  -- Maximum time. If h hours have elpased, then complete the current iteration and stop. Default no time limit.
    muscle3 -in ${fasta} -out ${id}.afa -maxhours ${task.time.toHours() - 2}
    """
}

process build_hmms {
    tag "ca_hmms_${id}"
    publishDir "${params.final_output_dir}/data/hmms/${seq_type}", mode: "copy", pattern: "*.{hmm,json,png}"

    input:
        tuple val(id), path(msa), val(seq_type)
    output:
        tuple val(seq_type), path("${id}.hmm"), emit: hmms
        path("${id}.json"), emit: json

    script:
    """
    hmmbuild ${id}.hmm ${msa}
    python ${projectDir}/logo/convert_hmm_to_skylign_json.py --hmm ${id}.hmm --json ${id}.json --png ${id}.png
    """
}

process zip_hmms {
    tag "ca_hmms_zip"
    publishDir params.final_output_dir, mode: "copy", pattern: "*.zip"

    input:
        tuple val(seq_type), path(input_hmms)
    output:
        path("hmms_${seq_type}.zip")

    script:
    """
    dir="hmms"
    mkdir \$dir
    cp *.hmm \$dir
    zip -rq "hmms_${seq_type}.zip" \$dir
    rm -rf \$dir
    """
}

process make_weblogos {
    tag "ca_weblogos_${id}"
    publishDir "${params.final_output_dir}/data/weblogos/${seq_type}", mode: "copy", pattern: "*.png"

    input:
        tuple val(id), path(msa), val(seq_type)
    output:
        tuple val(seq_type), path("${id}.png"), emit: pngs
        tuple val(seq_type), path("${id}_sm.png"), emit: sm_pngs
        tuple val(seq_type), path("${id}.txt"), emit: logos

    script:

    // Assign a color to the residues that the user provided as input (e.g. first is red, second
    // is blue, etc)
    def colors = ["red", "blue", "orange", "DarkGreen", "Magenta", "Gray"]
    def color_args = ""
    params.conserved_residues.eachWithIndex { res, i ->
        if (i < colors.size()) {
            color_args += " --color ${colors[i]} ${res} ${res}"
        }
    }

    """
    weblogo -D fasta -F png_print --stacks-per-line 80 -f ${msa} -o ${id}.png ${color_args}
    weblogo -D fasta -F png -s small --stacks-per-line 80 -f ${msa} -o ${id}_sm.png ${color_args}
    weblogo -D fasta -F logodata -f ${msa} -o ${id}.txt
    """
}

process zip_weblogos {
    tag "ca_weblogos_zip"
    publishDir params.final_output_dir, mode: "copy", pattern: "*.zip"

    input:
        tuple val(seq_type), path(input_pngs)
    output:
        path("weblogos_${seq_type}.zip")

    script:
    """
    dir="weblogos"
    mkdir \$dir
    cp *.png \$dir
    zip -rq "weblogos_${seq_type}.zip" \$dir
    rm -rf \$dir
    """
}

process run_clustal_omega {
    tag "ca_clustal_${id}"
    label "APP_clustalo"

    // Ignore any clustal computations because we don't want a failure to block the pipeline.
    // This output isn't crucial.
    errorStrategy 'ignore'

    input:
        tuple val(id), path(msa), val(seq_type)
    output:
        tuple val(seq_type), path("${id}_pim.txt")

    script:
    """
    clustalo -i ${msa} --percent-id --distmat-out=${id}_pim.txt --full --force --threads=${task.cpus}
    """
}

process zip_clustal_omega {
    tag "ca_clustal_zip"
    publishDir params.final_output_dir, mode: "copy", pattern: "*.zip"

    input:
        tuple val(seq_type), path(input_pims)
    output:
        path("clustal_pims_${seq_type}.zip")

    script:
    """
    dir="clustal_pims_${seq_type}"
    mkdir \$dir
    cp *_pim.txt \$dir
    zip -rq "clustal_pims_${seq_type}.zip" \$dir
    rm -rf \$dir
    """
}

process collect_aa_ids {
    tag "ca_count_msa_aa"
    publishDir "${params.final_output_dir}/data/cons_res/${type}/consensus_residue_results_${aa}", mode: "copy", pattern: "*.txt"

    input:
        tuple path("msa_files/*"), path("logo_files/*"), path(cluster_size_file), path(mapping_file), val(aa), val(threshold), val(type)
    output:
        tuple val(aa), val(threshold), path("consensus_residue_${aa}_${threshold}_position.txt"), path("consensus_residue_${aa}_${threshold}_percentage.txt"), val(type)

    script:
    def base_name = "consensus_residue_${aa}_${threshold}"
    """
    perl $projectDir/conv_ratio/count_msa_aa.pl \
        --msa-dir msa_files \
        --logo-dir logo_files \
        --aa ${aa} \
        --count-file ${base_name}_position.txt \
        --pct-file ${base_name}_percentage.txt \
        --threshold ${threshold} \
        --node-count-file ${cluster_size_file}
    mkdir id_lists_${threshold}
    perl $projectDir/conv_ratio/collect_aa_ids.pl \
        --aa-count-file ${base_name}_position.txt \
        --output-dir id_lists_${threshold} \
        --id-mapping ${mapping_file}
    """
}

process summarize_msa_aa {
    tag "ca_summarize_msa_aa"
    publishDir "${params.final_output_dir}/data/cons_res/${seq_type}", mode: "copy", pattern: "*.txt"

    input:
        tuple val(seq_type), val(aa), path(pos_files), path(pct_files)
    output:
        path("*.txt")

    script:
    def base_name = "ConsensusResidue_${aa}"
    """
    perl $projectDir/conv_ratio/make_summary_tables.pl --position-summary-file ${base_name}_Position_Summary_Full.txt --percentage-summary-file ${base_name}_Percentage_Summary_Full.txt --position-files ${pos_files} --percentage-files ${pct_files}
    """
}

workflow ALIGN_AND_ANALYZE {
    take:
        prepared_fasta_ch
        id_cluster_mapping

    main:

        //
        // STEP 4: PERFORM MULTIPLE SEQUENCE ALIGNMENT
        // 

        // Compute the cluster size file
        cluster_size_file = prepared_fasta_ch
            .branch {
                domain_seq: it[0] =~ /_domain/
                full_seq:   true
            }
            .full_seq
            .map { type, id, fasta, seq_type, num_seq -> "${id}\t${num_seq}\n" }
            .concat( Channel.of("cluster_id\tnum_seq\n") )
            .collectFile(
                name: "msa_cluster_size.txt",
                storeDir: params.final_output_dir,
                keepHeader: false,
                sort: { item ->
                    if (item.startsWith("cluster_id\t")) return -1
                    return item.split('\t')[1].toInteger()
                }
            )

        // We only need cluster ID and FASTA file for the MSA
        analysis_fasta_ch = prepared_fasta_ch.map { type, id, fasta, seq_type, num_seq -> tuple(id, fasta, type =~ /_domain/ ? "domain" : "full") }

        // Perform alignment using MUSCLE
        if (params.muscle_version == 3) {
            msa_ch = muscle3_align(analysis_fasta_ch)
        } else {
            msa_ch = muscle5_align(analysis_fasta_ch)
        }

        //
        // STEP 5: BUILD HMMS AND COMPUTE WEBLOGOS
        //

        // Create HMMs
        hmms = build_hmms(msa_ch)
        zip_hmms(hmms.hmms.groupTuple())

        // Create weblogo graphics and logo data file
        if (params.make_weblogos) {
            weblogo_ch = make_weblogos(msa_ch)
            zip_weblogos(weblogo_ch.pngs.groupTuple())

            //
            // STEP 6: ANALYZE CONSERVED RESIDUES AND PID MATRICES
            //

            // Compute consensus residues
            cr_params_ch = Channel.from(params.conserved_residues)
                .combine(Channel.from(params.pid_thresholds))
            msa_groups = msa_ch.map { id, file, type -> [type, file] }.groupTuple()
            logo_groups = weblogo_ch.logos.groupTuple()

            collect_aa_input = msa_groups
                .join(logo_groups)
                .combine(cr_params_ch)
                .combine(cluster_size_file)
                .combine(id_cluster_mapping)
                .map { type, msas, logos, aa, threshold, cluster_size_file, id_cluster_mapping ->
                    tuple(msas, logos, cluster_size_file, id_cluster_mapping, aa, threshold, type)
                }
            counted_residues_ch = collect_aa_ids(collect_aa_input)

            // groupTuple allows us to create a structure that looks like [AA, [pos_files, ...], [pct_files, ...]]
            residues_ch = counted_residues_ch
                .map { aa, threshold, pos_file, pct_file, seq_type -> tuple(seq_type, aa, pos_file, pct_file) }
                .groupTuple(by: [0, 1])
            summarize_msa_aa(residues_ch)
        }

        // Compute percent ID matrices using Clustal-Omega
        clustal_files = run_clustal_omega(msa_ch)

        zip_clustal_omega(clustal_files.groupTuple())
}
