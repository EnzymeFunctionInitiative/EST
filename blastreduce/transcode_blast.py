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
    parser.add_argument("--blast-output", type=str, nargs="+", help="Path to directory containing the BLAST output files")
    parser.add_argument("--transcoded-output", nargs="+", type=str)
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
    if not all(map(os.path.exists, args.blast_output)):
        print(f"BLAST output '{args.blast_output}' does not exist")
        fail = True
    if fail:
        exit(1)
    else:
        return args

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

def csv_to_parquet_file(filename: str, output: str, read_options: csv.ReadOptions, parse_options: csv.ParseOptions, convert_options: csv.ConvertOptions) -> pq.ParquetFile:
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
    writer = pq.ParquetWriter(output, data.schema)
    for batch in data:
        writer.write_batch(batch)
    writer.close()

if __name__ == "__main__":
    args = parse_args()
    if len(args.blast_output) != len(args.transcoded_output):
        exit(1)
    else:
        for blast_output, transcoded_output in zip(args.blast_output, args.transcoded_output):
            csv_to_parquet_file(blast_output, transcoded_output, read_options, parse_options, convert_options)
