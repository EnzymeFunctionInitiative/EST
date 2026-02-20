
include { ALIGN_AND_ANALYZE } from "./subworkflows/msa.nf"
include { color_and_retrieve } from "../shared/nextflow/color_workflow.nf"
include { MAKE_HISTOGRAMS } from "./subworkflows/length_histograms.nf"
include { PREPARE_FASTA } from "./subworkflows/prepare.nf"

workflow {
    // Files are published to params.final_output_dir by the processes inside the
    // color_and_retrieve workflow
    color_work = color_and_retrieve()

    prepared_fasta_ch = PREPARE_FASTA(color_work.fasta_files, color_work.sequence_type)

    ALIGN_AND_ANALYZE(prepared_fasta_ch.analysis_fasta, color_work.mapping_table)

    histograms = MAKE_HISTOGRAMS(prepared_fasta_ch.color_fasta)
}
