SET memory_limit = '$mem_limit';
SET temp_directory = '$duckdb_temp_dir';
SET threads TO 1;
SET preserve_insertion_order = false;

COPY (
    SELECT qseqid, sseqid, pident, alignment_length, bitscore, query_length, subject_length
    FROM read_parquet('$blast_output')
    WHERE $filter_parameter >= $min_val AND
          query_length >= $min_length AND
          subject_length >= $min_length AND
          (query_length <= $max_length AND subject_length <= $max_length) OR $max_length = 0
) TO '$filtered_blast_output' (FORMAT 'CSV', HEADER false, DELIMITER '\t')