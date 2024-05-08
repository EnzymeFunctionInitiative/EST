SET memory_limit = '$mem_limit';
SET temp_directory = '$duckdb_temp_dir';
SET threads TO 1;
SET preserve_insertion_order = false;

-- compute boxplot stats for percent identity and aligment length
CREATE TABLE statistics AS (
    SELECT alignment_score,
           COUNT(qseqid) as edge_count,
           MIN(pident) as pident_whislo,
           quantile_cont(pident, .25) as pident_q1,
           median(pident) as pident_med,
           quantile_cont(pident, .75) as pident_q3,
           MAX(pident) as pident_whishi,
           MIN(alignment_length) as al_whislo,
           quantile_cont(alignment_length, .25) as al_q1,
           median(alignment_length) as al_med,
           quantile_cont(alignment_length, .75) as al_q3,
           MAX(alignment_length) as al_whishi,
    FROM read_parquet('../data/29855/1.out.parquet')
    GROUP BY alignment_score
);

-- export pident boxplot stats
COPY (
    SELECT alignment_score,
           pident_whislo as whislo,
           pident_q1 as q1,
           pident_med as med,
           pident_q3 as q3,
           pident_whishi as whishi
    FROM statistics
    ORDER BY alignment_score ASC
) TO '$pident_boxplot_file' (FORMAT 'parquet', COMPRESSION '$compression');

-- export alignment length boxplot stats
COPY (
    SELECT alignment_score,
           al_whislo as whislo,
           al_q1 as q1,
           al_med as med,
           al_q3 as q3,
           al_whishi as whishi
    FROM statistics
    ORDER BY alignment_score ASC
) TO '$alignment_length_boxplot_file' (FORMAT 'parquet', COMPRESSION '$compression');

-- export edge counts
COPY (
    SELECT alignment_score, edge_count, SUM(edge_count) OVER (ORDER BY alignment_score DESC) as cumulative_edge_count
    FROM statistics
    ORDER BY alignment_score ASC;
) TO '$evalue_file' (HEADER false, DELIMITER '\t');