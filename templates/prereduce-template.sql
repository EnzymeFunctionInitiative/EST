SET threads TO 1;
SET preserve_insertion_order = false;

-- read BLAST data from transcoded parquet files, ignore sequences aligned
-- against themselves.
CREATE TABLE blast_results as (
        SELECT * FROM read_parquet('$transcoded_blast_output_glob')
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

COPY (
    SELECT *
    FROM blast_results
) TO '$prereduce_output_file' (FORMAT 'parquet', COMPRESSION '$compression');