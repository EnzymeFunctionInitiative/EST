import argparse
import os
import string

from pyEFI import sql_template_render

def add_custom_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--blast-output", type=str, help="Path to directory containing the BLAST output files")
    parser.add_argument(
        "--boxplot-stats-output",
        type=str,
        default="boxplot_stats.parquet",
        help="Output filename for percent identity and alignment length statistics. Will be Parquet.",
    )
    parser.add_argument(
        "--evalue-output",
        type=str,
        default="evalue.tab",
        help="Output filename for edge count file",
    )

def create_parser():
    parser = sql_template_render.create_sql_template_render_parser("../templates/boxplotstats-template.sql", "Render sql to compute boxplot stats and produce evalue.tab", "boxplotstats.sql")
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
        "blast_parquet": args.blast_output,
        "boxplot_stats_file": args.boxplot_stats_output,
        "edge_counts_file": args.evalue_output,
        "compression": "zstd",
    }
    sql_template_render.render(args.sql_template, mapping, args.sql_output_file)