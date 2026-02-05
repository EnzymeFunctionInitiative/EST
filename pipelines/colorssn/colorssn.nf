include { color_and_retrieve } from "../shared/nextflow/color_workflow.nf"

workflow {
    // Files are published to params.final_output_dir by the processes inside the
    // color_and_retrieve workflow
    color_work = color_and_retrieve()
}

