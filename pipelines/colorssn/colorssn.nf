include { color_and_retrieve } from "../shared/nextflow/color_workflow.nf"

workflow {
    cr_work = color_and_retrieve()
}

