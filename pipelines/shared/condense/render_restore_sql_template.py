import argparse
import os
import string

from pyEFI import sql_template_render

def add_custom_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--blast-parquet", type=str, help="Path to the condensed BLAST parquet file.")

def create_parser() -> argparse.ArgumentParser:
    parser = sql_template_render.create_sql_template_render_parser(
        "../templates/restore-template.sql",
        "Render the DuckDB SQL template for restoring all blast edges from the condensed sequence set",
        sql_output_file = "restore.sql"
    )
    return parser

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    if not os.path.exists(args.blast_parquet):
        print(f"Input blast parquet file '{args.blast_parquet}' does not exist")
        exit(1)
    return args

if __name__ == "__main__":
    parser = create_parser()
    add_custom_arguments(parser)
    args = parser.parse_args()
    args = check_args(args)
    mapping = {
        "mem_limit": args.duckdb_memory_limit,
        "n_threads": args.duckdb_n_threads,
        "duckdb_temp_dir": args.duckdb_temp_dir,
        "blast_parquet": args.blast_parquet
    }
    sql_template_render.render(args.sql_template, mapping, args.sql_output_file)
