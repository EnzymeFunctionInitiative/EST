SET memory_limit = '$mem_limit';
SET temp_directory = '$duckdb_temp_dir';
SET threads TO 1;

-- read BLAST data from transcoded parquet files, ignore sequences aligned
-- against themselves.
CREATE TABLE blast_results as (
        SELECT * FROM read_parquet($transcoded_blast_output_glob)
        WHERE NOT qseqid = sseqid
);

--
-- this section is a compare-and swap on qseqid and sseqid so that qseqid <
-- sseqid. This could be done in one operation but it takes more memory and
-- can cause an error so it is split into two
--
ALTER TABLE blast_results ADD COLUMN smallseqid STRING;
ALTER TABLE blast_results ADD COLUMN largeseqid STRING;

UPDATE blast_results 
SET smallseqid = LEAST(UPPER(blast_results.qseqid), UPPER(blast_results.sseqid));

UPDATE blast_results
SET largeseqid = GREATEST(UPPER(blast_results.qseqid), UPPER(blast_results.sseqid));

ALTER TABLE blast_results DROP qseqid;
ALTER TABLE blast_results DROP sseqid;
ALTER TABLE blast_results RENAME smallseqid TO qseqid;
ALTER TABLE blast_results RENAME largeseqid TO sseqid;

--
-- The original blastreduce uses a sort + picking the first occurrence of a
-- (qseqid, sseqid) pair to deduplicate. That is replicated here by paritioning
-- on (qseqid, sseqid) and assigning a rank to a specific sorted order. It does
-- not exactly match the previous method but it is extremly close
CREATE TABLE reduced AS
    SELECT *
    FROM (
        SELECT qseqid, sseqid, pident, alignment_length, bitscore,
        ROW_NUMBER() OVER (PARTITION BY qseqid, sseqid
                           ORDER BY bitscore DESC, pident ASC, alignment_length ASC) ranked_order
        FROM blast_results
    ) t
    WHERE t.ranked_order = 1;

DROP TABLE blast_results;

--
-- attach sequence lengths to each row
--
-- read sequence lengths from transcoded FASTA-lengths file
CREATE TABLE sequence_lengths as (
    SELECT * FROM read_parquet('$fasta_lengths_parquet')
);

ALTER TABLE reduced ADD COLUMN query_length INT32;
ALTER TABLE reduced ADD COLUMN subject_length INT32;

UPDATE reduced
SET query_length = (SELECT sequence_length FROM sequence_lengths WHERE reduced.qseqid = sequence_lengths.seqid);

UPDATE reduced
SET subject_length = (SELECT sequence_length FROM sequence_lengths WHERE reduced.sseqid = sequence_lengths.seqid);

DROP TABLE sequence_lengths;

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
           CAST(FLOOR(-1 * log10(query_length * subject_length) + log10(2) * bitscore) AS INT32) as alignment_score
    FROM reduced
    ORDER BY alignment_score DESC
)
TO '$reduce_output_file' (FORMAT 'parquet', COMPRESSION '$compression');
