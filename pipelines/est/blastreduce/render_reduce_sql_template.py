import argparse
import os
import string

from pyEFI import sql_template_render

def add_custom_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--blast-output", type=str, nargs="+", help="Path to directory containing the BLAST output files")
    parser.add_argument("--fasta-length-parquet", type=str, help="Path to the FASTA file to transcode")
    parser.add_argument(
        "--output-file",
        type=str,
        default="1.out.parquet",
        help="The final output file the aggregated BLAST output should be written to. Will be Parquet.",
    )

def create_parser() -> argparse.ArgumentParser:
    parser = sql_template_render.create_sql_template_render_parser("../templates/reduce-template.sql", "Render the DuckDB SQL template for eliminating duplicate and self edges", sql_output_file="reduce.sql")
    return parser

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    fail = False
    if not all(map(os.path.exists, args.blast_output)):
        print(f"At least one of BLAST output '{args.blast_output}' does not exist")
        fail = True
    if not os.path.exists(args.fasta_length_parquet):
        print(f"FASTA length parquet file '{args.fasta_length_parquet}' does not exist")
        fail = True

    if fail:
        exit(1)
    else:
        args.blast_output = list(map(os.path.abspath, args.blast_output))
        args.fasta_length_parquet = os.path.abspath(args.fasta_length_parquet)
        return args

if __name__ == "__main__":
    parser = create_parser()
    add_custom_arguments(parser)
    args = parser.parse_args()
    args = check_args(args)
    mapping = {
        "mem_limit": args.duckdb_memory_limit,
        "duckdb_temp_dir": args.duckdb_temp_dir,
        "transcoded_blast_output_glob": str(args.blast_output),
        "fasta_lengths_parquet": args.fasta_length_parquet,
        "reduce_output_file": args.output_file,
        "compression": "zstd",
    }
    sql_template_render.render(args.sql_template, mapping, args.sql_output_file)