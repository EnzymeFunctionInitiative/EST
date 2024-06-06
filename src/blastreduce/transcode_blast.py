import argparse
import glob
import os
import string

from Bio import SeqIO
from pyarrow import csv
import pyarrow.parquet as pq
import pyarrow as pa


def parse_args():
    parser = argparse.ArgumentParser(description="Transcode BLAST output files to Parquet")
    parser.add_argument("--blast-output", type=str, nargs="+", help="BLAST output files")

    args = parser.parse_args()

    # validate input filepaths
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
        "evalue": pa.float32(),
        "bitscore": pa.float32(),
    },
    include_columns=["qseqid", "sseqid", "pident", "alignment_length", "bitscore"]
)

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
    output = f"{os.path.basename(filename)}.parquet"
    writer = pq.ParquetWriter(output, data.schema)
    for batch in data:
        writer.write_batch(batch)
    writer.close()

if __name__ == "__main__":
    args = parse_args()
    for blast_output in args.blast_output:
        csv_to_parquet_file(blast_output, read_options, parse_options, convert_options)
