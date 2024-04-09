Transcode
=========

Tab-delimited ASCII files are convenient to use but hurt performance. To more
efficiently post-process BLAST results, the BLAST output files are transcoded to
Parquet files.

The conversion only includes the columns needed in later stages.

In addition to the BLAST output, a FASTA file can be transcoded into a table
which holds sequence identifiers + sequence lengths. This is also used in later analysis.

Finally, this module contains code to generate, from a template, a SQL file which:

1. Deduplicates BLAST outputs
2. Adds sequence length information
3. Calculates an alignment score for each row
4. Combines all output shards into one Parquet file

Commandline usage
------------------

.. highlight:: none

::

    usage: transcode.py [-h] [--blast-output BLAST_OUTPUT] [--fasta FASTA] [--sql-template SQL_TEMPLATE]
                        [--sql-output-file SQL_OUTPUT_FILE] [--duckdb-memory-limit DUCKDB_MEMORY_LIMIT]
                        [--duckdb-temp-dir DUCKDB_TEMP_DIR] [--output-file OUTPUT_FILE]

    Transcode BLAST output files and FASTA sequence lengths to Parquet

    options:
    -h, --help            show this help message and exit
    --blast-output BLAST_OUTPUT
                            Path to directory containing the BLAST output files
    --fasta FASTA         Path to the FASTA file to transcode
    --sql-template SQL_TEMPLATE
                            Path to the template sql file for reduce operations
    --sql-output-file SQL_OUTPUT_FILE
                            Location to write the reduce SQL commands to
    --duckdb-memory-limit DUCKDB_MEMORY_LIMIT
                            Soft limit on DuckDB memory usage
    --duckdb-temp-dir DUCKDB_TEMP_DIR
                            Location DuckDB should use for temporary files
    --output-file OUTPUT_FILE
                            The final output file the aggregated BLAST output should be written to. Will be Parquet.

Functions
---------

.. automodule:: blastreduce.transcode
        :members: