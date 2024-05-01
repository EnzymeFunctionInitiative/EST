
from transcode import *

def parse_args():
    parser = argparse.ArgumentParser(description="Transcode BLAST output files and FASTA sequence lengths to Parquet")
    parser.add_argument("--blast-output", type=str, nargs="+", help="Path to directory containing the BLAST output files")
    parser.add_argument("--fasta-length-parquet", type=str, help="Path to the FASTA file to transcode")
    parser.add_argument(
        "--sql-template",
        type=str,
        default="../templates/reduce-template.sql",
        help="Path to the template sql file for reduce operations",
    )
    parser.add_argument(
        "--sql-output-file",
        type=str,
        default="reduce.sql",
        help="Location to write the reduce SQL commands to",
    )
    parser.add_argument("--duckdb-memory-limit", type=str, default="4GB", help="Soft limit on DuckDB memory usage")
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

if __name__ == "__main__":
    args = parse_args()
    render_sql_from_template(
                args.sql_template,
                args.sql_output_file,
                args.duckdb_memory_limit,
                args.duckdb_temp_dir,
                args.blast_output,
                args.fasta_length_parquet,
                args.output_file,
            )