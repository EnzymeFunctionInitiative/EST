import argparse
import os

from pyarrow import csv
import pyarrow as pa

from pyEFI.transcode import csv_to_parquet

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

if __name__ == "__main__":
    args = check_args(create_parser().parse_args())
    for blast_output in args.blast_output:
        csv_to_parquet(blast_output, read_options, parse_options, convert_options)
