SET memory_limit = '$mem_limit';
SET temp_directory = '$duckdb_temp_dir';
SET threads TO '$n_threads';

COPY (
    SELECT *
    FROM read_parquet('$blast_parquet')
) TO 'condensed.out' (FORMAT CSV, DELIMITER '\t', HEADER false);
