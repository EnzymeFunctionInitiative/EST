process get_id_list {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path id_list
    output:
        path 'id_lists/', emit: 'id_lists'
    """
    mkdir id_lists
    echo 'AAA' > id_lists/aaa.txt
    echo 'BBB' > id_lists/bbb.txt
    echo 'CCC' > id_lists/ccc.txt
    """
}

