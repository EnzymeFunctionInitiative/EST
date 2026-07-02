SET memory_limit = '$mem_limit';
SET temp_directory = '$duckdb_temp_dir';
SET threads TO '$n_threads';
SET preserve_insertion_order = false;

COPY (
    SELECT
        b.qseqid,
        b.sseqid,
        b.pident,
        b.alignment_length,
        b.bitscore,
        b.query_length,
        b.subject_length,
        b.alignment_score
    FROM read_parquet('$blast_output') b
    JOIN read_csv('$filtered_ids_file', header=False, columns={'id': 'VARCHAR'}) m1
      ON b.qseqid = m1.id
    JOIN read_csv('$filtered_ids_file', header=False, columns={'id': 'VARCHAR'}) m2
      ON b.sseqid = m2.id
    WHERE
        b.$threshold_metric >= $threshold_min_val AND
        b.query_length >= $min_length AND
        b.subject_length >= $min_length AND
        (
            (b.query_length <= $max_length AND b.subject_length <= $max_length)
            OR $max_length = 0
        )
) TO '$thresholded_blast_output' (FORMAT 'CSV', HEADER false, DELIMITER '\t')
