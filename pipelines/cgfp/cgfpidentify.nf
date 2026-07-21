
include { COMPUTE_COLOR_CLUSTER_WORKFLOW } from "../shared/nextflow/color_workflow.nf"
include { get_sequences } from "../shared/nextflow/sequence.nf"
include { merge_stats; unzip_ssn } from "../shared/nextflow/util.nf"
include { condense_redundant } from "../shared/nextflow/blast.nf"

process get_fasta_id_list {
    input:
        path cluster_id_map
    output:
        path "id_list.txt"

    script:
    """
    cut -f1 ${cluster_id_map} > id_list.txt
    """
}

process create_marker_ssn {
    publishDir params.final_output_dir, mode: "copy", pattern: "{marker_ssn.xgmml.zip}"

    input:
        path ssn_file
        path marker_file
        path cluster_id_map
        path cdhit_table
    output:
        path "marker_ssn.xgmml.zip", emit: "marker_ssn"
        path "marker_stats.json", emit: "stats"

    script:
    """
    #TODO: implement SSN creation
    touch marker_ssn.xgmml.zip #DEBUG
    echo '{}' > marker_stats.json
    """
}

process cgfp_identify {
    publishDir params.final_output_dir, mode: "copy", pattern: "{markers.faa}"

    input:
        path fasta_file
        val ref_db /* TODO: Path to a blast database */
    output:
        path "markers.faa", emit: "marker_file"
        path "id-temp/clust/clust.faa.clstr", emit: "cdhit"

    script:
    """
    mkdir id-temp
    #TODO: run shortbred
    """
}

process get_merged_fasta_file {
    input:
        path ssn_seq_file
        path fasta_file
    output:
        path "merged.fasta"

    script:
    // Sequences in the first file are kept, while sequences in the second file with the same
    // ID are discarded; otherwise the sequences from fasta_file are merged
    """
    seqkit rmdup -i ${ssn_seq_file} ${fasta_file} -o merged.fasta
    """
}

process create_cdhit_table {
    input:
        path cdhit_file
        path cluster_id_map
    output:
        "cdhit.tab"

    script:
    """
    perl $projectDir/prep/make_cdhit_table.pl --cdhit-file ${cdhit_file} --cluster-map ${cluster_id_map} --table-file cdhit.tab
    """
}

workflow {
    if (params.ssn_input =~ /\.zip$/) {
        ssn_file = unzip_ssn(Channel.value(file(params.ssn_input)))
    } else {
        ssn_file = Channel.value(file(params.ssn_input))
    }

    // Compute the clusters
    color_work = COMPUTE_COLOR_CLUSTER_WORKFLOW(ssn_file)

    // Get the FASTA based on the sequence IDs
    fasta_id_list_file = get_fasta_id_list(color_work.cluster_id_map)
    id_fasta_file = get_sequences(fasta_id_list_file, params.fasta_db)

    // Get the sequences that are defined in the SSN, then merge the sequences defined in the
    // SSN with the ones retrieved from the ID list. Overwrite any in the ID list FASTA with
    // the SSN FASTA.
    ssn_fasta_file = get_merged_fasta_file(color_work.ssn_sequences, id_fasta_file)

    condensed_fasta = condense_redundant(tuple("F", fasta_file)).map { id, file -> file }.first()

    //TODO: figure out what refdb is
    results = cgfp_identify(condensed_fasta.fasta_file, refdb)

    cdhit_table = create_cdhit_table(results.cdhit, color_work.cluster_id_map)

    marker_ssn_data = create_marker_ssn(ssn_file, results.marker_file, color_work.cluster_id_map, cdhit_table)

    stats_merge = color_work.cluster_stats.mix(marker_ssn_data.stats)
    stats_merge.collect().set { files_to_merge }
    final_stats = merge_stats(files_to_merge)
}

