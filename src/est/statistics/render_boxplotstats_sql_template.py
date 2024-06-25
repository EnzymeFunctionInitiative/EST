import argparse
import string

def create_parser():
    parser = argparse.ArgumentParser(description="Render sql to compute boxplot stats and produce evalue.tab")
    parser.add_argument("--blast-output", type=str, help="Path to directory containing the BLAST output files")
    parser.add_argument(
        "--sql-template",
        type=str,
        default="../templates/boxplotstats-template.sql",
        help="Path to the template sql file for reduce operations",
    )
    parser.add_argument(
        "--sql-output-file",
        type=str,
        default="boxplotstats.sql",
        help="Location to write the reduce SQL commands to",
    )
    parser.add_argument("--duckdb-memory-limit", type=str, default="8GB", help="Soft limit on DuckDB memory usage")
    parser.add_argument(
        "--duckdb-temp-dir",
        type=str,
        default="./duckdb",
        help="Location DuckDB should use for temporary files",
    )
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
    return parser

def render_sql_from_template(
    template_file: str,
    sql_output_file: str,
    mem_limit: str,
    duckdb_temp_dir: str,
    blast_parquet: str,
    boxplot_output: str,
    evalue_output: str
):
    """
    Creates a .sql file for deduplication and merging using newly created
    parquet files

    This function uses the python stdlib
    :external+python:py:class:`string.Template` to fill in file paths and other
    options in a SQL file. The SQL file is executed with `DuckDB
    <https://duckdb.org/>`_.

    Parameters
    ----------
        template_file
            Path to the template sql file for statistics operations
        mem_limit
            Soft limit for DuckDB memory usage. In bytes by default but can use common suffixes such as `MB and `GB`
        duckdb_temp_dir
            Location where duckdb should place its on-disk cache. Folder will be created if it does not exist
        
    """
    mapping = {
        "mem_limit": mem_limit,
        "duckdb_temp_dir": duckdb_temp_dir,
        "blast_parquet": blast_parquet,
        "boxplot_stats_file": boxplot_output,
        "edge_counts_file": evalue_output,
        "compression": "zstd",
    }
    with open(template_file) as f:
        template = string.Template(f.read())
        with open(sql_output_file, "w") as g:
            print(f"Saving template to '{sql_output_file}'")
            g.write(template.substitute(mapping))

if __name__ == "__main__":
    args = create_parser().parse_args()
    render_sql_from_template(
                args.sql_template,
                args.sql_output_file,
                args.duckdb_memory_limit,
                args.duckdb_temp_dir,
                args.blast_output,
                args.boxplot_stats_output,
                args.evalue_output
            )