import argparse
import glob
import os
import string

from Bio import SeqIO
from pyarrow import csv
import pyarrow.parquet as pq
import pyarrow as pa


def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Transcode demultiplexed BLAST output files to Parquet")
    parser.add_argument("--blast-output", type=str, nargs="+", help="BLAST output files")

    return parser

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    fail = False
    if not all(map(os.path.exists, args.blast_output)):
        print(f"At least one of BLAST output '{args.blast_output}' does not exist")
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
        "bitscore",
        "query_length",
        "subject_length",
        "alignment_score",
    ]
)
parse_options = csv.ParseOptions(delimiter="\t")
convert_options = csv.ConvertOptions(
    column_types={
        "qseqid": pa.string(),
        "sseqid": pa.string(),
        "pident": pa.float32(),
        "alignment_length": pa.uint32(),
        "bitscore": pa.float32(),
        "query_length": pa.uint32(),
        "subject_length": pa.uint32(),
        "alignment_score": pa.uint32()
    }
)

def csv_to_parquet_file(filename: str, read_options: csv.ReadOptions, parse_options: csv.ParseOptions, convert_options: csv.ConvertOptions) -> str:
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
        The name of the parquet file created
    """
    schema = pa.schema({k: convert_options.column_types[k] for k in convert_options.include_columns})
    output = f"{os.path.basename(filename)}.parquet"
    writer = pq.ParquetWriter(output, schema)
    try:
        data = csv.open_csv(
            filename,
            read_options=read_options,
            parse_options=parse_options,
            convert_options=convert_options,
        )
        for batch in data:
            writer.write_batch(batch)
    except pa.lib.ArrowInvalid as e:
        print(f"Error when opening '{filename}': {e}")
        print("Producing empty output file")
    
    writer.close()
    return output

if __name__ == "__main__":
    args = check_args(create_parser().parse_args())
    for blast_output in args.blast_output:
        csv_to_parquet_file(blast_output, read_options, parse_options, convert_options)
