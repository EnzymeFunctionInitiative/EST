
import argparse
import os
import re

import duckdb
import pyarrow as pa
import pyarrow.parquet as pq


def get_args() -> argparse.ArgumentParser:
    """
    Optain the command line arguments.

    Returns
    -------
        argparse Namespace containing the input parameters and output file path
    """
    parser = argparse.ArgumentParser(
        description="Remove self-alignment results from a blastout parquet file."
    )
    # file io arguments
    parser.add_argument(
        "--condensed-blast",
        type=str,
        required=True,
        help="Path to the BLAST out result parquet"
    )
    parser.add_argument(
        "--output-file",
        type=str,
        default="1.out.parquet",
        help="Output file path where the restored sequence set's BLAST results are written. Will be parquet."
    )
    # duckdb arguments
    parser.add_argument(
        "--duckdb-memory-limit",
        type=str,
        default="4GB",
        help="Soft limit on DuckDB memory usage"
    )
    parser.add_argument(
        "--duckdb-n-threads",
        type=int,
        default=1,
        help="Number of threads to use"
    )
    parser.add_argument(
        "--duckdb-compression",
        type=str,
        default="zstd",
        help="Type of compression to use in temporary files"
    )
    parser.add_argument(
        "--duckdb-temp-dir",
        type=str,
        default="./duckdb",
        help="Location DuckDB should use for temporary files"
    )
    return parser.parse_args()

def connect_duckdb(
        memory_limit: str,
        temp_dir: str,
        n_threads: int
    ) -> duckdb.DuckDBPyConnection:
    """
    Create a connection to a duckdb instance. Configure the connection to use
    the set amount of RAM, use a local temp storage directory if duckdb
    processing runs out of RAM, and use the set number of threads.

    Parameters
    ----------
        memory_limit
            str, format: XGB where X is the maximum integer value of memory
            allotable to duckdb (units of GB).
        temp_dir
            str, global path to a storage space where duckdb can write temp
            database file(s) if it goes beyond the memory limit set.
        n_threads
            int, number of threads available for duckdb to use.

    Returns
    -------
        connection to duckdb database in memory
    """

    # Initialize DuckDB connection with strict limits
    conn = duckdb.connect(database=':memory:')
    conn.execute(f"SET memory_limit='{memory_limit}';")
    conn.execute(f"SET temp_directory='{temp_dir}';")
    conn.execute(f"SET threads={n_threads};")
    #conn.execute(f"SET max_temp_directory_size = '100GB';")

    return conn

def close_duckdb(conn: duckdb.DuckDBPyConnection):
    """
    Close the connection to the duckdb instance.
    """
    conn.close()

def remove_self_alignments(
        conn: duckdb.DuckDBPyConnection,
        blast_out: str,
        output_file_path: str
    ):
    """
    Read the blast_out result file and remove unwanted self-alignment results.

    Parameters
    ----------
        conn
            duckdb.DuckDBPyConnection, a in-memory duckdb sql connection.
        condensed_blast
            str, path to the input condensed BLAST results parquet file.
        output_file_path
            str, path where the final parquet file will be written.

    Creates the further-reduced BLAST results parquet file, saved as
    f"{output_file_path}".
    """

    query = f"""
    COPY (
        SELECT *

        FROM read_parquet('{blast_out}') AS aln

        WHERE qseqid != sseqid

    ) TO '{output_file_path}' (FORMAT 'parquet');
    """
    conn.execute(query)
    print("Done removing self-alignments from the blast output file.")


if __name__ == "__main__":
    args = get_args()

    os.makedirs(args.duckdb_temp_dir, exist_ok=True)

    # Connect to the duckdb in-memory database
    conn = connect_duckdb(
        memory_limit = args.duckdb_memory_limit,
        temp_dir = args.duckdb_temp_dir,
        n_threads = args.duckdb_n_threads
    )

    # process the condensed blast result file along with CD-HIT cluster database
    remove_self_alignments(
        conn,
        args.condensed_blast,
        args.output_file
    )

    close_duckdb(conn)


