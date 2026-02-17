
process muscle5_align {
    tag "ca_muscle5_${type}_${id}"

    publishDir "${params.final_output_dir}/data/${type}/msa", mode: "copy", pattern: "*.afa"

    input:
        tuple val(type), val(id), path(fasta), val(seq_type), val(num_seq)

    output:
        tuple val(type), val(id), path("*.afa"), val(seq_type), val(num_seq), emit: msa

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
    tag "ca_muscle3_${type}_${id}"

    publishDir "${params.final_output_dir}/data/${type}/msa", mode: "copy", pattern: "*.afa"

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
        tuple val(type), val(id), path(fasta), val(seq_type), val(num_seq)

    output:
        tuple val(type), val(id), path("*.afa"), val(seq_type), val(num_seq), emit: msa

    script:
    """
    muscle3 -in ${fasta} -out ${id}.afa
    """
}

process build_hmms {
    tag "ca_hmms_${type}_${id}"

    publishDir "${params.final_output_dir}/data/${type}/hmms", mode: "copy", pattern: "*.hmm"
    publishDir "${params.final_output_dir}/data/${type}/hmms", mode: "copy", pattern: "*.json"

    input:
        tuple val(type), val(id), path(msa), val(seq_type), val(num_seq)

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
    tag "ca_weblogos_${type}_${id}"

    publishDir "${params.final_output_dir}/data/${type}/weblogos", mode: "copy", pattern: "*.png"

    input:
        tuple val(type), val(id), path(msa), val(seq_type), val(num_seq)

    output:
        path("*.png")
        path("*.txt")

    script:
    """
    weblogo -D fasta -F png --resolution 300 --stacks-per-line 80 -f ${msa} -o ${id}.png
    weblogo -D fasta -F logodata -f ${msa} -o ${id}.txt
    """
}

process run_clustal_omega {
    tag "ca_clustal_${type}_${id}"

    // Ignore any clustal computations because we don't want a failure to block the pipeline.
    // This output isn't crucial.
    errorStrategy 'ignore'

    input:
        tuple val(type), val(id), path(msa), val(seq_type), val(num_seq)

    output:
        tuple val(type), path("*_pim.txt")

    script:
    """
    clustalo -i ${msa} --percent-id --distmat-out=${id}_pim.txt --full --force
    """
}

process zip_clustal_omega {
    tag "ca_clustal_zip"
    
    publishDir params.final_output_dir, mode: "copy", pattern: "*.zip"

    input:
        tuple val(type), path(clustal_pims) // This looks like: ['uniprot', [file1.txt, file2.txt, ...]]

    output:
        path("*.zip")

    script:
    """
    if [ -n "${clustal_pims}" ]; then
        dir="clustal_pims_${type}"
        mkdir \$dir
        cp *.txt \$dir
        zip -r "clustal_pims_${type}.zip" \$dir
        rm -rf \$dir
    fi
    """
}

workflow align_and_analyze {
    take:
        analysis_fasta_ch

    main:
        // STEP 4: RUN MSA TO ALIGN SEQUENCES
    
        // Perform alignment using MUSCLE
        if (params.muscle_version == 3) {
            msa_ch = muscle3_align(analysis_fasta_ch)
        } else {
            msa_ch = muscle5_align(analysis_fasta_ch)
        }

        build_hmms(msa_ch)

        make_weblogos(msa_ch)

        clustal_ch = run_clustal_omega(msa_ch)
            .groupTuple()
        zip_clustal_omega(clustal_ch)

        if (params.pid_thresholds && !params.pid_thresholds.isEmpty()) {
            //clustal_inputs = msa_ch.combine(Channel.fromList(params.pid_thresholds))
            //clustal_inputs.view()
        }
}
