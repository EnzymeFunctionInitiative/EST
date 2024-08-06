import argparse
import os
import string

from pyEFI import sql_template_render

def add_custom_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--blast-output", type=str, required=True, help="Path to directory containing the BLAST output file")
    parser.add_argument(
        "--output-file",
        type=str,
        required=True,
        help="The final output file the aggregated BLAST output should be written to. Will be Parquet.",
    )

def create_parser() -> argparse.ArgumentParser:
    parser = sql_template_render.create_sql_template_render_parser("../templates/prereduce-template.sql", "Render the DuckDB SQL template for alphabetizing IDs", sql_output_file="prereduce.sql")
    return parser

def check_args(args: argparse.ArgumentParser) -> argparse.Namespace:
    fail = False
    if not os.path.exists(args.blast_output):
        print(f"BLAST output '{args.blast_output}' does not exist")
        fail = True
    if fail:
        exit(1)
    else:
        args.blast_output = os.path.abspath(args.blast_output)
        return args

if __name__ == "__main__":
    parser = create_parser()
    add_custom_arguments(parser)
    args = parser.parse_args()
    args = check_args(args)
    mapping = {
        "mem_limit": args.duckdb_memory_limit,
        "duckdb_temp_dir": args.duckdb_temp_dir,
        "transcoded_blast_output_glob": args.blast_output,
        "prereduce_output_file": args.output_file,
        "compression": "zstd",
    }
    sql_template_render.render(args.sql_template, mapping, args.sql_output_file)