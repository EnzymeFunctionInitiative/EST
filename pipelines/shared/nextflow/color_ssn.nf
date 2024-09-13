process color_ssn {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path ssn_file
    output:
        path 'ssn_colored.xgmml', emit: 'ssn_output'
        path 'id_list.txt', emit: 'id_list'
    """
    touch ssn_colored.xgmml
    touch id_list.txt
    """
}

