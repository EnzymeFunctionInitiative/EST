import argparse
import glob
import os
import string

from Bio import SeqIO
from pyarrow import csv
import pyarrow.parquet as pq
import pyarrow as pa


def parse_args():
    parser = argparse.ArgumentParser(description="Transcode BLAST output files and FASTA sequence lengths to Parquet")
    parser.add_argument("--blast-output", type=str, help="Path to directory containing the BLAST output files")
    parser.add_argument("--fasta", type=str, help="Path to the FASTA file to transcode")
    parser.add_argument(
        "--sql-template",
        type=str,
        default="reduce-template.sql",
        help="Path to the template sql file for reduce operations",
    )
    parser.add_argument(
        "--sql-output-file",
        type=str,
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
    parser.add_argument(
        "--output-file",
        type=str,
        default="1.out.parquet",
        help="The final output file the aggregated BLAST output should be written to. Will be Parquet.",
    )

    args = parser.parse_args()

    # validate input filepaths
    fail = False
    if not os.path.exists(args.blast_output):
        print(f"BLAST output '{args.blast_output}' does not exist")
        fail = True
    if not os.path.exists(args.fasta):
        print(f"FASTA file '{args.fasta}' does not exist")
        fail = True
    if not os.path.exists(args.sql_template):
        print(f"SQL template '{args.sql_template}' does not exist")
        fail = True
    if fail:
        exit(1)
    else:
        return args


def csv_to_parquet_file(filename: str, read_options: csv.ReadOptions, parse_options: csv.ParseOptions, convert_options: csv.ConvertOptions) -> pq.ParquetFile:
    """
    Convert a single CSV file to a Parquet file using the supplied options

    Parameters
    ----------
        filename
            The path to the CSV file
        read_options
            Read Options
        parse_options
            Parse Options
        convert_options
            Convert Options
    
    Returns
    -------
            A ParquetFile object representing the transcoded input file. Name will be `filename`.parquet
    """
    data = csv.open_csv(
        filename,
        read_options=read_options,
        parse_options=parse_options,
        convert_options=convert_options,
    )
    new_name = filename + ".parquet"
    writer = pq.ParquetWriter(new_name, data.schema)
    for batch in data:
        writer.write_batch(batch)
    writer.close()

    return new_name

def csvs_to_parquets(blast_directory: str) -> str:
    """
    Convert csv files to Parquet Dataset
    
    This function defines the read_options, parse_options, and convert_options
    needed to correctly interpret BLAST output. It the gathers a list of BLAST
    output files from the specified directory using a glob pattern and passes
    the resulting file paths to the :func:`csv_to_parquet_file` function for
    conversion.

    Parameters
    ----------
        blast_directory
            Location of BLAST output files. Should contain many `.fa.tab` files

    Returns
    -------
        A string containing a glob for the new parquet files

    Warning
    -------
        Will exit if no BLAST output files are found.
    
    """
    # https://edwards.flinders.edu.au/blast-output-8/
    read_options = csv.ReadOptions(
        column_names=[
            "qseqid",
            "sseqid",
            "pident",
            "alignment_length",
            "mismatches",
            "gap_openings",
            "qstart",
            "qend",
            "sstart",
            "send",
            "evalue",
            "bitscore",
        ]
    )
    parse_options = csv.ParseOptions(delimiter="\t")
    convert_options = csv.ConvertOptions(
        column_types={
            "qseqid": pa.string(),
            "sseqid": pa.string(),
            "pident": pa.float32(),
            "alignment_length": pa.int32(),
            "mismatches": pa.int32(),
            "gap_openings": pa.int32(),
            "qstart": pa.int32(),
            "qend": pa.int32(),
            "sstart": pa.int32(),
            "send": pa.int32(),
            "evale": pa.float32(),
            "bitscore": pa.float32(),
        },
        include_columns=["qseqid", "sseqid", "pident", "alignment_length", "bitscore"],
    )
    # glob just the .tab files for safety
    files = glob.glob(os.path.join(blast_directory, "*.fa.tab"))
    if len(files) == 0:
        print("No BLAST output found; exiting")
        exit(1)
    print(f"Converting {len(files)} files")

    for file in files:
        print(f"Converting {file}")
        csv_to_parquet_file(file, read_options, parse_options, convert_options)

    return os.path.join(blast_directory, "*.parquet")


def fasta_to_parquet(fasta_file: str) -> str:
    """
    Converts the provided FASTA file into a 2-column parquet file with columns `seqid` and `sequence_length`

    Parameters
    ----------
        fasta_file
            path to the FASTA file
    
    Returns
    -------
        The filename of the new parquet files as `fasta_file`.parquet
    """
    ids, lengths = [], []
    for record in SeqIO.parse(fasta_file, "fasta"):
        ids.append(record.id)
        lengths.append(len(record.seq))
    ids = pa.array(ids)
    lengths = pa.array(lengths)
    tbl = pa.Table.from_arrays([ids, lengths], names=["seqid", "sequence_length"])
    filename = f"{fasta_file}.parquet"
    pq.write_table(tbl, filename)
    return filename


def render_sql_from_template(
    template_file: str,
    mem_limit: str,
    duckdb_temp_dir: str,
    blast_output_glob: str,
    fasta_lengths_parquet: str,
    reduce_output_file: str,
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
            Path to the template sql file for reduce operations
        mem_limit
            Soft limit for DuckDB memory usage. In bytes by default but can use common suffixes such as `MB and `GB`
        duckdb_temp_dir
            Location where duckdb should place its on-disk cache. Folder will be created if it does not exist
        blast_output_glob
            Globbed path to Parquet-encoded BLAST output files to combine (from :func:`csvs_to_parquets`)
        fasta_lengths_parquet
            Path to the parquet file with columns `seqid` and `sequence_lengths` (from :func:`fasta_to_parquet`)
        reduce_output_file
            Location to which the combined output (in Parquet format) should be written
    """
    mapping = {
        "mem_limit": mem_limit,
        "duckdb_temp_dir": duckdb_temp_dir,
        "transcoded_blast_output_glob": blast_output_glob,
        "fasta_lengths_parquet": fasta_lengths_parquet,
        "reduce_output_file": reduce_output_file,
        "compression": "zstd",
    }
    with open(template_file) as f:
        template = string.Template(f.read())
        with open(args.sql_output_file, "w") as g:
            print(f"Saving template to '{args.sql_output_file}'")
            g.write(template.substitute(mapping))


if __name__ == "__main__":
    args = parse_args()
    if args.blast_output or args.fasta:
        if args.blast_output is not None:
            blast_output_glob = csvs_to_parquets(args.blast_output)
        if args.fasta is not None:
            fasta_lengths_parquet = fasta_to_parquet(args.fasta)
        if args.blast_output and args.fasta:
            render_sql_from_template(
                args.sql_template,
                args.duckdb_memory_limit,
                args.duckdb_temp_dir,
                blast_output_glob,
                fasta_lengths_parquet,
                args.output_file,
            )
    else:
        print("No input specified, nothing to do")
