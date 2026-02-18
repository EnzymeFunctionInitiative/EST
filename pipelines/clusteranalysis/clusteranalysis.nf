
include { align_and_analyze } from "./subworkflows/msa.nf"
include { color_and_retrieve } from "../shared/nextflow/color_workflow.nf"
include { make_histograms } from "./subworkflows/length_histograms.nf"
include { prepare_fasta } from "./subworkflows/prepare.nf"

workflow {
    // Files are published to params.final_output_dir by the processes inside the
    // color_and_retrieve workflow
    color_work = color_and_retrieve()

    prepared_fasta_ch = prepare_fasta(color_work.fasta_files, color_work.sequence_type)

    align_and_analyze(prepared_fasta_ch.analysis_fasta)

    histograms = make_histograms(prepared_fasta_ch.color_fasta)
}
