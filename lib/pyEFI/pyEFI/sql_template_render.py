import argparse
import string

from typing import Any

class SQLTemplateRenderer:
    """A class to help render DuckDB SQL templates"""
    def __init__(self, sql_template_file: str):
        """
        Parameters
        ----------
            sql_template_file
                Location of the SQL template. Will be used as the default for
                the ``--sql-template-file`` parameter
        """
        self.sql_template_file = sql_template_file
        self.parser = None
        self.params = {}

    def create_argparser(self, desc: str) -> argparse.ArgumentParser:
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
            default=self.sql_template_file,
            help="Path to the template sql file",
        )
        parser.add_argument(
            "--sql-output-file",
            type=argparse.FileType('w+'),
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


    def render(self, mapping: dict[str, Any], sql_output_file: str):
        """
        Render SQL file

        Parameters
        ----------
            mapping
                Replacements for every variable defined in the SQL template
            
            sql_output_file
                The location to write the SQL file. This will likely be
                ``create_argparser().parse_args().sql_output_file``
        """
        with open(self.sql_template_file) as f:
            template = string.Template(f.read())
            with open(self.sql_output_file, "w") as g:
                print(f"Saving template to '{sql_output_file}'")
                g.write(template.substitute(mapping))