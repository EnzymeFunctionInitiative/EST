import argparse
import duckdb
import glob
import math
import os
import re
import shutil

# Rough ratio of in-memory size (decoded columns plus hash table) to on-disk size of the
# zstd-compressed BLAST parquet data. Used only to pick a default number of buckets.
IN_MEMORY_EXPANSION = 10
MAX_AUTO_BUCKETS = 1024

# Column order and types of the final output file
OUTPUT_COLUMNS = """
    qseqid, sseqid, pident, alignment_length, bitscore, query_length, subject_length, alignment_score
"""


def get_args() -> argparse.ArgumentParser:
    """
    Obtain the command line arguments.

    Returns
    -------
        argparse Namespace containing the input parameters and output file path
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("--blast-output", type=str, nargs="+", help="Paths to the BLAST output parquet files (one per shard)")
    parser.add_argument("--fasta-length-parquet", type=str, help="Path to the parquet file containing sequence lengths")
    parser.add_argument("--duckdb-memory-limit", type=str, default="4GB", help="Soft limit on DuckDB memory usage")
    parser.add_argument("--duckdb-n-threads", type=int, default=1, help="Number of threads to use")
    parser.add_argument("--duckdb-compression", type=str, default="zstd", help="Type of compression to use in temporary files")
    parser.add_argument(
        "--duckdb-temp-dir",
        type=str,
        default="./duckdb",
        help="Location DuckDB should use for temporary files",
    )
    parser.add_argument(
        "--num-buckets",
        type=int,
        default=0,
        help="Number of hash buckets to split the BLAST pairs into; each bucket is reduced independently. "
             "0 (default) picks a value from the input size and the DuckDB memory limit.",
    )
    parser.add_argument(
        "--output-file",
        type=str,
        default="1.out.parquet",
        help="The final output file the aggregated BLAST output should be written to. Will be Parquet.",
    )
    return parser.parse_args()


def connect_duckdb(args: argparse.Namespace) -> duckdb.DuckDBPyConnection:
    """
    Create a connection to a duckdb instance.  We do computations using the duckdb library.
    duckdb pages data to local temp storage directory if it runs out of RAM.

    Parameters
    ----------
        args
            argparse Namespace containing duckdb parameters

    Returns
    -------
        connection to duckdb database in memory
    """

    # Initialize DuckDB connection with strict limits
    conn = duckdb.connect(database=':memory:')
    conn.execute(f"SET memory_limit='{args.duckdb_memory_limit}';")
    conn.execute(f"SET temp_directory='{args.duckdb_temp_dir}';")
    conn.execute(f"SET threads={args.duckdb_n_threads};")
    # Row order is never relied on until the final ORDER BY; not preserving it lets DuckDB
    # stream and spill with less memory.
    conn.execute("SET preserve_insertion_order=false;")

    return conn


def parse_memory_limit(limit: str) -> int:
    """
    Convert a DuckDB memory limit string (e.g. "6553MiB", "8GB") into bytes.  DuckDB treats
    KB/MB/GB/TB as powers of 1000 and KiB/MiB/GiB/TiB as powers of 1024.

    Parameters
    ----------
        limit
            memory limit string

    Returns
    -------
        number of bytes
    """
    units = {
        "": 1, "B": 1,
        "KB": 1000, "MB": 1000**2, "GB": 1000**3, "TB": 1000**4,
        "KIB": 1024, "MIB": 1024**2, "GIB": 1024**3, "TIB": 1024**4,
    }
    match = re.fullmatch(r"\s*([0-9]*\.?[0-9]+)\s*([A-Za-z]*)\s*", limit)
    if not match or match.group(2).upper() not in units:
        raise ValueError(f"Unable to parse DuckDB memory limit '{limit}'")
    return int(float(match.group(1)) * units[match.group(2).upper()])


def choose_num_buckets(args: argparse.Namespace) -> int:
    """
    Pick how many hash buckets to split the BLAST pairs into.  Every bucket must be reduced
    in memory (spilling is possible but slow), so the estimated in-memory size of one bucket
    should be comfortably below the DuckDB memory limit.

    Parameters
    ----------
        args
            argparse Namespace containing the BLAST files, memory limit and --num-buckets

    Returns
    -------
        number of buckets (>= 1)
    """
    if args.num_buckets > 0:
        return args.num_buckets

    input_bytes = sum(os.path.getsize(f) for f in args.blast_output)
    memory_bytes = parse_memory_limit(args.duckdb_memory_limit)
    # Aim for a bucket that uses at most half of the memory limit once expanded
    num_buckets = math.ceil(input_bytes * IN_MEMORY_EXPANSION / (memory_bytes / 2))
    return max(1, min(num_buckets, MAX_AUTO_BUCKETS))


def partition_input(args: argparse.Namespace, conn: duckdb.DuckDBPyConnection, bucket_dir: str, num_buckets: int):
    """
    Split every BLAST shard into hash buckets on (qseqid, sseqid).  The all_by_all_blast
    step already ordered each pair so that qseqid <= sseqid, so every copy of a pair (A->B
    from A's shard, B->A from B's shard, repeated HSPs) lands in the same bucket.  Buckets
    can then be de-duplicated independently, which bounds the memory needed to the size of
    one bucket instead of the whole dataset.

    Output is a hive-partitioned directory: bucket_dir/bucket=<n>/shard_<i>_<j>.parquet

    Parameters
    ----------
        args
            argparse Namespace containing path to the input BLAST parquet files
        conn
            duckdb connection object
        bucket_dir
            directory to write the bucketed files to
        num_buckets
            number of hash buckets
    """
    print(f"Partitioning {len(args.blast_output)} files into {num_buckets} buckets...")
    for i, file in enumerate(args.blast_output):
        # Each shard is written separately so that the memory used for buffering the
        # partitioned write is bounded by the size of one shard.
        query = f"""
        COPY (
            SELECT
                qseqid, sseqid, pident, alignment_length, bitscore,
                hash(qseqid, sseqid) % {num_buckets} AS bucket
            FROM read_parquet('{file}')
        ) TO '{bucket_dir}' (
            FORMAT 'parquet',
            PARTITION_BY (bucket),
            FILENAME_PATTERN 'shard_{i}_{{i}}',
            OVERWRITE_OR_IGNORE
        );
        """
        conn.execute(query)
        print(f"Partitioned file {i+1}/{len(args.blast_output)}")


def reduce_buckets(args: argparse.Namespace, conn: duckdb.DuckDBPyConnection, bucket_dir: str, reduced_dir: str, num_buckets: int):
    """
    De-duplicate each bucket, attach sequence lengths and compute the alignment score.

    Parameters
    ----------
        args
            argparse Namespace containing the sequence length file and compression
        conn
            duckdb connection object
        bucket_dir
            directory containing the bucketed files from partition_input
        reduced_dir
            directory to write one reduced parquet file per bucket to
        num_buckets
            number of hash buckets
    """
    print("Loading sequence lengths...")
    conn.execute(f"CREATE TABLE seq_lens AS SELECT * FROM read_parquet('{args.fasta_length_parquet}');")

    for b in range(num_buckets):
        bucket_path = os.path.join(bucket_dir, f"bucket={b}")
        # A bucket can be empty for small inputs
        if not os.path.isdir(bucket_path):
            continue

        # This query does three things:
        #     1. Keeps one row per (qseqid, sseqid) pair.  The row kept is the one with the
        #        highest bitscore, then lowest pident, then lowest alignment_length, which is
        #        the same order the previous ROW_NUMBER() window used.  arg_max over a struct
        #        is a hash aggregate, which uses less memory than a window and can spill.
        #     2. Attaches query and subject sequence lengths.
        #     3. Computes the alignment score.
        query = f"""
        COPY (
            WITH dedup AS (
                SELECT
                    qseqid, sseqid,
                    arg_max(
                        {{'pident': pident, 'alignment_length': alignment_length, 'bitscore': bitscore}},
                        {{'bitscore': bitscore, 'pident': -pident, 'alignment_length': -alignment_length}}
                    ) AS best
                FROM read_parquet('{bucket_path}/*.parquet')
                GROUP BY qseqid, sseqid
            )
            SELECT
                d.qseqid, d.sseqid,
                d.best.pident AS pident,
                d.best.alignment_length AS alignment_length,
                d.best.bitscore AS bitscore,
                CAST(ql.sequence_length AS INT32) AS query_length,
                CAST(sl.sequence_length AS INT32) AS subject_length,
                CAST(FLOOR(-1 * log10(CAST(ql.sequence_length AS DOUBLE) * CAST(sl.sequence_length AS DOUBLE)) + log10(2) * d.best.bitscore) AS INT32) AS alignment_score
            FROM dedup d
            JOIN seq_lens ql ON d.qseqid = ql.seqid
            JOIN seq_lens sl ON d.sseqid = sl.seqid
        ) TO '{os.path.join(reduced_dir, f"bucket_{b}.parquet")}' (FORMAT 'parquet', COMPRESSION '{args.duckdb_compression}');
        """
        conn.execute(query)

        # Free the disk space as we go; the bucket is no longer needed
        shutil.rmtree(bucket_path)
        print(f"Reduced bucket {b+1}/{num_buckets}")


def merge_and_sort(args: argparse.Namespace, conn: duckdb.DuckDBPyConnection, reduced_dir: str):
    """
    Merge the reduced buckets into the final output file, sorted by alignment score
    (descending).  No de-duplication is needed here because every pair lives in exactly
    one bucket.  DuckDB's sort spills to the temp directory when it does not fit in memory.

    Parameters
    ----------
        args
            argparse Namespace containing the output file path and compression
        conn
            duckdb connection object
        reduced_dir
            directory containing the reduced bucket files
    """
    print("Merging buckets and sorting...")
    if glob.glob(os.path.join(reduced_dir, "*.parquet")):
        source = f"read_parquet('{os.path.join(reduced_dir, '*.parquet')}')"
    else:
        # No BLAST hits at all; write an empty file with the expected schema
        source = """(
            SELECT
                NULL::VARCHAR AS qseqid, NULL::VARCHAR AS sseqid, NULL::FLOAT AS pident,
                NULL::INT32 AS alignment_length, NULL::FLOAT AS bitscore, NULL::INT32 AS query_length,
                NULL::INT32 AS subject_length, NULL::INT32 AS alignment_score
            WHERE false
        )"""

    final_query = f"""
    COPY (
        SELECT {OUTPUT_COLUMNS}
        FROM {source}
        ORDER BY alignment_score DESC
    ) TO '{args.output_file}' (FORMAT 'parquet', COMPRESSION '{args.duckdb_compression}');
    """
    conn.execute(final_query)


if __name__ == "__main__":
    args = get_args()
    os.makedirs(args.duckdb_temp_dir, exist_ok=True)
    bucket_dir = os.path.join(args.duckdb_temp_dir, "buckets")
    reduced_dir = os.path.join(args.duckdb_temp_dir, "reduced")
    os.makedirs(reduced_dir, exist_ok=True)

    num_buckets = choose_num_buckets(args)
    conn = connect_duckdb(args)
    partition_input(args, conn, bucket_dir, num_buckets)
    reduce_buckets(args, conn, bucket_dir, reduced_dir, num_buckets)
    merge_and_sort(args, conn, reduced_dir)
    conn.close()
