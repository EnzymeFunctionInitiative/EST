
include { COLOR_AND_RETRIEVE } from "../shared/nextflow/color_workflow.nf"
include { merge_stats; unzip_ssn; zip_files } from "../shared/nextflow/util.nf"
include { color_ssn } from "../shared/nextflow/color_xgmml.nf"
include { ALIGN_AND_ANALYZE } from "./subworkflows/msa.nf"
include { MAKE_HISTOGRAMS } from "./subworkflows/length_histograms.nf"
include { PREPARE_FASTA } from "./subworkflows/prepare.nf"

workflow {
    if (params.ssn_input =~ /\.zip$/) {
        ssn_file = unzip_ssn(Channel.value(file(params.ssn_input)))
    } else {
        ssn_file = Channel.value(file(params.ssn_input))
    }

    // Run the COLOR_AND_RETRIEVE workflow to get the FASTA sequences from the input SSN as 
    // well as other SSN-related metadata.  Files are published to params.final_output_dir by
    // the processes inside the COLOR_AND_RETRIEVE workflow
    color_work = COLOR_AND_RETRIEVE(ssn_file)

    // PREPARE: Get FASTA files for the histograms and the MSA-based analyses
    prepared_fasta_ch = PREPARE_FASTA(color_work.fasta_files, color_work.sequence_type)

    if (params.make_hmms) {
        // ANALYZE: Perform a MSA, create weblogos and HMMs, and compute other analyses
        ALIGN_AND_ANALYZE(prepared_fasta_ch.analysis_fasta, color_work.mapping_table)
    }

    // PLOT: Plot a length histogram for each cluster
    if (params.make_length_histograms) {
        MAKE_HISTOGRAMS(prepared_fasta_ch.color_fasta)
    }

    // Color the SSN based on the computed clusters
    colored_ssn = color_ssn(color_work.ssn_file, color_work.cluster_id_map, color_work.cluster_num_map, color_work.cluster_colors)

    // Zip SSN file
    zipped_files = zip_files(colored_ssn.ssn)

    stats_merge = color_work.cluster_stats.mix(colored_ssn.stats)
    stats_merge.collect().set { files_to_merge }
    final_stats = merge_stats(files_to_merge)
}
