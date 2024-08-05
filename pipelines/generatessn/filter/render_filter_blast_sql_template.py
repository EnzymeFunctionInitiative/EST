import argparse
import string
import os

from pyEFI import sql_template_render

def add_custom_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--blast-output", type=str, required=True, help="Path to directory containing the reduced BLAST output file")
    parser.add_argument(
        "--output-file",
        type=str,
        required=True,
        help="The final output file the filtered BLAST output should be written to. Will be tab-separated"
    )
    parser.add_argument(
        "--filter-parameter",
        type=str,
        required=True,
        choices=["pident", "bitscore", "alignment_score"],
        help="The parameter to filter on"
    )
    parser.add_argument(
        "--filter-min-val",
        type=float,
        required=True,
        help="The minimum value for the selected filter. Values below are not kept"
    )
    parser.add_argument(
        "--min-length",
        type=int,
        default=0,
        help="Minimum sequence length required to retain row"
    )
    parser.add_argument(
        "--max-length",
        type=int,
        default=0,
        help="Maximum sequence length allowed in retained rows"
    )

def create_parser() -> argparse.ArgumentParser:
    parser = sql_template_render.create_sql_template_render_parser("../templates/filterblast-template.sql", "Filter reduced BLAST output on specified parameter", "filterblast.sql")
    return parser

def check_args(args: argparse.Namespace) -> argparse.Namespace:
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
        "blast_output": args.blast_output,
        "filter_parameter": args.filter_parameter,
        "min_val": args.filter_min_val,
        "min_length": args.min_length,
        "max_length": args.max_length,
        "filtered_blast_output": args.output_file,
        "compression": "zstd",
    }
    sql_template_render.render(args.sql_template, mapping, args.sql_output_file)