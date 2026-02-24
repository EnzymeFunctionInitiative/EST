import argparse
from io import TextIOWrapper
import string
import tempfile

from typing import Any

def get_temp_dir_name() -> str:
    """
    Use tempfile.TemporaryDirectory() to create a temp directory space, gather
    the path for that space, and automatically delete the empty directory.
    Return the path to duckdb during sql template rendering.
    """
    temp_dir = tempfile.TemporaryDirectory(ignore_cleanup_errors = True)
    temp_path = temp_dir.name
    temp_dir.cleanup()
    return temp_path

def create_sql_template_render_parser(
        sql_template_file_default: str,
        desc: str,
        duckdb_temp_dir: str,
        sql_output_file: str = "statements.sql",
        duckdb_mem_limit: str = "4GB"
    ) -> argparse.ArgumentParser:
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
        # if left undefined, will create a randomly generated directory name in
        # the system's defined temp space
        default = get_temp_dir_name(),
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
