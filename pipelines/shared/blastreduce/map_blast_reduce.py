import argparse
import duckdb
import glob
import os

def get_args() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--blast-output", type=str, nargs="+", help="Path to directory containing the BLAST output files")
    parser.add_argument("--fasta-length-parquet", type=str, help="Path to the FASTA file to transcode")
    parser.add_argument("--duckdb-memory-limit", type=str, default="4GB", help="Soft limit on DuckDB memory usage")
    parser.add_argument("--duckdb-threads", type=int, default=1, help="Number of threads to use")
    parser.add_argument("--duckdb-compression", type=str, default="zstd", help="Type of compression to use in temporary files")
    parser.add_argument(
        "--duckdb-temp-dir",
        type=str,
        default="./duckdb",
        help="Location DuckDB should use for temporary files",
    )
    parser.add_argument(
        "--output-file",
        type=str,
        default="1.out.parquet",
        help="The final output file the aggregated BLAST output should be written to. Will be Parquet.",
    )
    return parser.parse_args()

def connect_duckdb(args: argparse.Namespace) -> duckdb.DuckDBPyConnection:

    # Initialize DuckDB connection with strict limits
    conn = duckdb.connect(database=':memory:')
    conn.execute(f"SET memory_limit='{args.duckdb_memory_limit}';")
    conn.execute(f"SET temp_directory='{args.duckdb_temp_dir}';")
    conn.execute("SET threads={args.duckdb_threads};")

    return conn

def load_input(args: argparse.Namespace, conn: duckdb.DuckDBPyConnection):
    os.makedirs(args.duckdb_temp_dir, exist_ok=True)

    print("Loading sequence lengths...")
    conn.execute(f"CREATE TABLE seq_lens AS SELECT * FROM read_parquet('{args.fasta_length_parquet}');")

    # Process each file individually and deduplicate
    print(f"Processing {len(args.blast_output)} files individually for deduplication...")
    for i, file in enumerate(args.blast_output):
        temp_out = os.path.join(args.duckdb_temp_dir, f"chunk_{i}.parquet")

        query = f"""
        COPY (
            WITH local_dedup AS (
                SELECT qseqid, sseqid, pident, alignment_length, bitscore
                FROM (
                    SELECT *, ROW_NUMBER() OVER (
                        PARTITION BY qseqid, sseqid
                        ORDER BY bitscore DESC, pident ASC, alignment_length ASC
                    ) as rn
                    FROM read_parquet('{file}')
                ) WHERE rn = 1
            ),
            enriched AS (
                SELECT
                    b.qseqid, b.sseqid, b.pident, b.alignment_length, b.bitscore,
                    CAST(ql.sequence_length AS INT32) AS query_length,
                    CAST(sl.sequence_length AS INT32) AS subject_length,
                    CAST(FLOOR(-1 * log10(CAST(ql.sequence_length AS DOUBLE) * CAST(sl.sequence_length AS DOUBLE)) + log10(2) * b.bitscore) AS INT32) AS alignment_score
                FROM local_dedup b
                JOIN seq_lens ql ON b.qseqid = ql.seqid
                JOIN seq_lens sl ON b.sseqid = sl.seqid
            )
            SELECT * FROM enriched
        ) TO '{temp_out}' (FORMAT 'parquet');
        """
        conn.execute(query)
        print(f"Processed file {i+1}/{len(args.blast_output)}")

def merge_and_sort(args: argparse.Namespace, conn: duckdb.DuckDBPyConnection):

    # Global merge and final sort
    print("Starting Phase 2: Global merge and final sort...")
    temp_glob = os.path.join(args.duckdb_temp_dir, "chunk_*.parquet")

    final_query = f"""
    COPY (
        WITH global_dedup AS (
            SELECT qseqid, sseqid, pident, alignment_length, bitscore, query_length, subject_length, alignment_score
            FROM (
                SELECT *, ROW_NUMBER() OVER (
                    PARTITION BY qseqid, sseqid
                    ORDER BY bitscore DESC, pident ASC, alignment_length ASC
                ) as rn
                FROM read_parquet('{temp_glob}')
            ) WHERE rn = 1
        )
        SELECT * FROM global_dedup
        ORDER BY alignment_score DESC
    ) TO '{args.output_file}' (FORMAT 'parquet', COMPRESSION '{args.compression}');
    """
    conn.execute(final_query)


if __name__ == "__main__":
    args = get_args()
    conn = connect_duckdb(args)
    load_input(args, conn)
    merge_and_sort(args, conn)
