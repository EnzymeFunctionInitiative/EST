
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
        description="Restore condensed BLAST results to the full sequence set."
    )
    # file io arguments
    parser.add_argument(
        "--cd-hit-cluster",
        type=str,
        required=True,
        help="Path to the CD-HIT cluster file"
    )
    parser.add_argument(
        "--condensed-blast",
        type=str,
        required=True,
        help="Path to the condensed BLAST result parquet"
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
        "--duckdb-threads",
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
    parser.add_argument(
        "--use-old-method",
        type=bool,
        default=False,
        help="Past versions of did not include intra-cluster edges. Will be mirrored if set to True"
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

def process_cd_hit_clusters(clstr_file: str, output_path: str):
    """
    Read the CD-HIT cluster file and stash the map between sequence ID and
    associated representative sequence ID in a temporary parquet file.

    Parameters
    ----------
        clstr_file
            str, path to the CD-HIT cluster file. Expected format detailed in
            https://www.bioinformatics.org/cd-hit/cd-hit-user-guide.

        output_path
            str, path to the temporary storage space where the map.parquet
            file will be written.

    Creates the map file in f"{output_path}/map.parquet"
    """
    cluster_mapping = {"seq_id":[], "rep_id": []}
    current_rep = None

    # Regex to extract ID between '>' and '...'
    # Example: 0	200aa, >SeqID... *
    id_pattern = re.compile(r">(.*?)\.\.\.")

    with open(clstr_file, "r") as f:
        for line in f:
            line = line.strip()
            # ">Cluster ###" lines indicate a new rep seq and associated
            # degenerate sequences.
            if line.startswith(">Cluster"):
                current_rep = None
            else:
                # match the regex pattern for the seq_id
                matched_id = id_pattern.search(line)
                if matched_id:
                    seq_id = matched_id.group(1)
                    # rep seq lines end with "*"
                    if line.endswith("*"):
                        current_rep = seq_id

                    cluster_mapping["seq_id"].append(seq_id)
                    if current_rep:
                        cluster_mapping["rep_id"].append(current_rep)
                    else:
                        print(line)
                        cluster_mapping["rep_id"].append(seq_id)

    table = pa.Table.from_pydict(cluster_mapping)
    pq.write_table(table, f"{output_path}/map.parquet")
    return f"{output_path}/map.parquet"

def restore_blast_results(
        conn: duckdb.DuckDBPyConnection,
        cluster_parquet: str,
        condensed_blast: str,
        output_file_path: str,
        old_method_bool: bool = False
    ):
    """
    Read the reduced but still condensed BLAST results parquet file then
    uncondense those results based on the CD-HIT cluster mapping parquet. Use
    condensed self-alignment results to fill in missing BLAST results. Finally,
    remove self-alignments and output the final blast parquet file.

    Parameters
    ----------
        conn
            duckdb.DuckDBPyConnection, a in-memory duckdb sql connection.
        cluster_parquet
            str, path to the map.parquet file created in previous step.
        condensed_blast
            str, path to the input condensed BLAST results parquet file.
        output_file_path
            str, path where the final parquet file will be written.
        old_method_bool
            bool, if True, ignore intra-cluster alignment results equivalent
            to ignoring edges between 100% identical sequences.

    Creates the reduced, uncondensed BLAST results parquet file, saved as
    f"{output_file_path}".
    """
    # Read in the cluster parquet file that contains the mapping of uncondensed
    # seqids to their condensed rep seq id.
    conn.execute(
        f"CREATE TABLE cluster_mapping AS SELECT * FROM read_parquet('{cluster_parquet}');"
    )

    # Expand all blast results using the cluster mapping using Cartesian
    # product of the sequence id set. Remove duplicates and self-alignments
    # here. Equivalent to filling in and reporting only the top triangle of the
    # 2d matrix, ignoring the diagonal.
    temp_out = os.path.join(args.duckdb_temp_dir, f"restored.parquet")

    # Prepare the query to do the uncondensing work.
    # Query strings generated using Chat-GPT:
    # https://chatgpt.com/share/6a106cef-be94-83ea-bba5-47e396f53c5d
    if old_method_bool:
        CONDITION = """
        /*
           This query removes self-alignments, duplicate edges, and
           intra-cluster alignments too (wrong to do so)
        */
        WHERE aln.qseqid != aln.sseqid AND qmap.seq_id < smap.seq_id
        """
    else:
        CONDITION = """
        /*
           This query removes self-alignments and duplicate edges.
        */
        WHERE qmap.seq_id < smap.seq_id
        """

    query = f"""
    COPY (
        SELECT
            qmap.seq_id AS qseqid,
            smap.seq_id AS sseqid,
            aln.* EXCLUDE (qseqid, sseqid)

        FROM read_parquet('{condensed_blast}') AS aln

        JOIN cluster_mapping AS qmap ON aln.qseqid = qmap.rep_id

        JOIN cluster_mapping AS smap ON aln.sseqid = smap.rep_id

        {CONDITION}

    ) TO '{output_file_path}' (FORMAT 'parquet');
    """
    conn.execute(query)
    print("Done restoring the condensed blast results file to its full glory.")


if __name__ == "__main__":
    args = get_args()

    os.makedirs(args.duckdb_temp_dir, exist_ok=True)

    # process the CD-HIT cluster file
    cluster_parquet = process_cd_hit_clusters(
        args.cd_hit_cluster,
        args.duckdb_temp_dir    # maybe should just be written in nf work dir "./"
    )

    # Connect to the duckdb in-memory database
    conn = connect_duckdb(
        memory_limit = args.duckdb_memory_limit,
        temp_dir = args.duckdb_temp_dir,
        n_threads = args.duckdb_threads
    )

    # process the condensed blast result file along with CD-HIT cluster database
    restore_blast_results(
        conn,
        cluster_parquet,
        args.condensed_blast,
        args.output_file,
        args.use_old_method
    )

    close_duckdb(conn)


