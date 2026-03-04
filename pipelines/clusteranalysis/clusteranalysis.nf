
include { ALIGN_AND_ANALYZE } from "./subworkflows/msa.nf"
include { color_and_retrieve } from "../shared/nextflow/color_workflow.nf"
include { MAKE_HISTOGRAMS } from "./subworkflows/length_histograms.nf"
include { PREPARE_FASTA } from "./subworkflows/prepare.nf"

workflow {
    // Run the color_and_retrieve workflow to get the FASTA sequences from the input SSN as 
    // well as other SSN-related metadata.  Files are published to params.final_output_dir by
    // the processes inside the color_and_retrieve workflow
    color_work = color_and_retrieve()

    // PREPARE: Get FASTA files for the histograms and the MSA-based analyses
    prepared_fasta_ch = PREPARE_FASTA(color_work.fasta_files, color_work.sequence_type)

    // ANALYZE: Perform a MSA, create weblogos and HMMs, and compute other analyses
    ALIGN_AND_ANALYZE(prepared_fasta_ch.analysis_fasta, color_work.mapping_table)

    // PLOT: Plot a length histogram for each cluster
    histograms = MAKE_HISTOGRAMS(prepared_fasta_ch.color_fasta)
}
