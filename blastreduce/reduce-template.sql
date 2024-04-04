SET memory_limit = '$mem_limit';
SET temp_directory = '$duckdb_temp_dir';
SET threads TO 1;

-- read BLAST data from transcoded parquet files, ignore sequences aligned
-- against themselves.
--
-- We need to order by several fields here so that the DISTINCT ON (qseqid,
-- sseqid) later on picks the correct row (which appears first because of the
-- sort) when faced with duplicates. This replicates the functionality from the
-- Perl version of BLASTreduce. If DISTINCT ON ever stops working by picking the
-- first occurence, this will break.
CREATE TABLE blast_results as (
        SELECT * FROM read_parquet('$transcoded_blast_output_glob')
        WHERE NOT qseqid = sseqid
        ORDER BY bitscore DESC, pident ASC, alignment_length ASC
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

--
-- Calculating new columns and sorting int the same step takes more memory.
-- Instead we create a temporary table that stores the finalized columns then
-- select from it
--
CREATE TEMP TABLE unsorted AS
SELECT DISTINCT ON(qseqid, sseqid) qseqid, 
                                   sseqid, 
                                   pident, 
                                   alignment_length,
                                   bitscore,
                                   query_length,
                                   subject_length,
                                   CAST(FLOOR(-1 * log10(query_length * subject_length) + log10(2) * bitscore) AS INT32) as alignment_score
    FROM blast_results;

-- export table back to parquet file, sorted by alignment score descending --
-- this allows for optimal grouping in the next stage
COPY (
    SELECT * FROM unsorted
    ORDER BY alignment_score DESC
)
TO '$reduce_output_file' (FORMAT 'parquet', COMPRESSION '$compression');
