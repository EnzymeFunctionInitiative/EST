SET memory_limit = '$mem_limit';
SET temp_directory = '$duckdb_temp_dir';
SET threads TO 1;

COPY (
    SELECT *
    FROM read_parquet('$blast_parquet')
) TO 'condensed.out' (FORMAT CSV, DELIMITER '\t', HEADER false);
