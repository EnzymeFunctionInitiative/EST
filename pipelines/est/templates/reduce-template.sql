SET memory_limit = '$mem_limit';
SET temp_directory = '$duckdb_temp_dir';
SET threads TO 1;
SET preserve_insertion_order = false;

-- read BLAST data from transcoded parquet files, ignore sequences aligned
-- against themselves.
CREATE TABLE blast_results as (
        SELECT * FROM read_parquet($transcoded_blast_output_glob)
        WHERE NOT qseqid = sseqid
);

--
-- The original blastreduce uses a sort + picking the first occurrence of a
-- (qseqid, sseqid) pair to deduplicate. That is replicated here by paritioning
-- on (qseqid, sseqid) and assigning a rank to a specific sorted order. It does
-- not exactly match the previous method but it is extremly close
CREATE TABLE reduced AS
    SELECT qseqid, sseqid, pident, alignment_length, bitscore
    FROM (
        SELECT qseqid, sseqid, pident, alignment_length, bitscore, ROW_NUMBER() 
        OVER (PARTITION BY qseqid, sseqid
              ORDER BY bitscore DESC, pident ASC, alignment_length ASC) ranked_order
        FROM blast_results
    ) t
    WHERE t.ranked_order = 1;

DROP TABLE blast_results;
ALTER TABLE reduced RENAME TO blast_results;

--
-- attach sequence lengths to each row
--
-- read sequence lengths from transcoded FASTA-lengths file
CREATE TABLE sequence_lengths as (
    SELECT * FROM read_parquet('$fasta_lengths_parquet')
);

ALTER TABLE blast_results ADD COLUMN query_length INT32;
ALTER TABLE blast_results ADD COLUMN subject_length INT32;

UPDATE blast_results
SET query_length = (SELECT sequence_length FROM sequence_lengths WHERE blast_results.qseqid = sequence_lengths.seqid);

UPDATE blast_results
SET subject_length = (SELECT sequence_length FROM sequence_lengths WHERE blast_results.sseqid = sequence_lengths.seqid);

DROP TABLE sequence_lengths;

-- add alignment score
ALTER TABLE blast_results ADD COLUMN alignment_score INT32;
UPDATE blast_results SET alignment_score = CAST(FLOOR(-1 * log10(query_length * subject_length) + log10(2) * bitscore) AS INT32);

-- export table back to parquet file, sorted by alignment score descending --
-- this allows for optimal grouping in the next stage
COPY (
    SELECT qseqid,
           sseqid,
           pident,
           alignment_length,
           bitscore,
           query_length,
           subject_length,
           alignment_score,
    FROM blast_results
    ORDER BY alignment_score DESC
)
TO '$reduce_output_file' (FORMAT 'parquet', COMPRESSION '$compression');
