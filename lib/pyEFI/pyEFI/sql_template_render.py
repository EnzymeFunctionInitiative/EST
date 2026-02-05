import argparse
from io import TextIOWrapper
import string

from typing import Any

def create_sql_template_render_parser(sql_template_file_default: str, desc: str, sql_output_file="statements.sql", duckdb_mem_limit="4GB", duckdb_temp_dir="./duckdb") -> argparse.ArgumentParser:
    """
    Returns an `<argparse.ArgumentParser>_` that parses the following
    options:

    * ``--sql-template``
    * ``--sql-output-file``
    * ``--duckdb-memory-limit``
    * ``--duckdb-temp-dir``

    These options are common to all DuckDB SQL templates. The intention is
    for arguments to be added to the return value of this function.

    Parameters
    ----------
        desc
            Description to be passed to the ``description`` parameter of
            the ``ArgumentParser`` constructor

    Returns
    -------
        An :external+python:py:class:`argparse.ArgumentParser` object
    """
    parser = argparse.ArgumentParser(description=desc)
    parser.add_argument(
        "--sql-template",
        type=argparse.FileType(),
        default=sql_template_file_default,
        help="Path to the template sql file",
    )
    parser.add_argument(
        "--sql-output-file",
        type=argparse.FileType('w+'),
        default=sql_output_file,
        help="Location to write the reduce SQL commands to",
    )
    parser.add_argument("--duckdb-memory-limit", type=str, default=duckdb_mem_limit, help="Soft limit on DuckDB memory usage")
    parser.add_argument(
        "--duckdb-temp-dir",
        type=str,
        default=duckdb_temp_dir,
        help="Location DuckDB should use for temporary files",
    )
    return parser

def render(sql_template_file: TextIOWrapper, mapping: dict[str, Any], sql_output_file: TextIOWrapper):
    """
    Render SQL file

    Parameters
    ----------
        sql_template_file
            The SQL template to use, will likely be
            ``create_sql_template_render_parser().parse_args().sql_template``

        mapping
            Replacements for every variable defined in the SQL template

        sql_output_file
            The location to write the SQL file. This will likely be
            ``create_sql_template_render_parser().parse_args().sql_output_file``
    """
    template = string.Template(sql_template_file.read())
    print(sql_output_file)
    print(f"Saving template to '{sql_output_file.name}'")
    sql_output_file.write(template.substitute(mapping))