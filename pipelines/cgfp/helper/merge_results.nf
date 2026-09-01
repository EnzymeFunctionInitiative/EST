
process merge_results {
    publishDir params.final_output_dir, mode: "copy", pattern: "{*.txt}"

    input:
        path result_files
        path ssn_cluster_file
        path ags_normalization_file
        val base_name
        val merge_type
    output:
        path "cluster_abundance${base_name}.txt", emit: "cluster"
        path "protein_abundance${base_name}.txt", emit: "protein"

    script:
    def merge_type_arg = ""
    if (merge_type == "normalized") {
        merge_type_arg = "-n"
    } else if (merge_type == "ags_normalized") {
        if (ags_normalization_file && file(ags_normalization_file).exists()) {
            merge_type_arg = "-g ${ags_normalization_file}"
        }
    }

    """
    python $projectDir/shortbred/merge_shortbred.py \
        ${result_files} \
        -c ${ssn_cluster_file} \
        -C "cluster_abundance${base_name}.txt" \
        -p "protein_abundance${base_name}.txt" \
        ${merge_type_arg}
    """
}

