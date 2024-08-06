import argparse
import json
import math
import os

import pyarrow.parquet as pq

from pyEFI.statistics import compute_conv_ratio

def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Compute convergence ratio for BLAST output")
    parser.add_argument("--blast-output", type=str, required=True, help="Path to transcoded BLAST parquet output parquet file from blastreduce")
    parser.add_argument("--fasta", type=str, required=True, help="Path to transcoded FASTA parquet file containing sequences")
    parser.add_argument("--output", type=str, required=True, help="Desired output filename")

    return parser

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    fail = False
    if not os.path.exists(args.blast_output):
        print(f"BLAST output '{args.blast_output}' does not exist")
        fail = True
    if not os.path.exists(args.fasta):
        print(f"FASTA file '{args.fasta}' does not exist")
        fail = True
    
    if fail:
        exit(1)
    else:
        args.blast_output = os.path.abspath(args.blast_output)
        args.fasta = os.path.abspath(args.fasta)
        return args


if __name__ == "__main__":
    args = check_args(create_parser().parse_args())
    edge_count = pq.ParquetFile(args.blast_output).metadata.num_rows
    node_count = pq.ParquetFile(args.fasta).metadata.num_rows
    conv_ratio = compute_conv_ratio(node_count, edge_count)
    output = {
        "ConvergenceRatio": conv_ratio,
        "EdgeCount": edge_count,
        "UniqueSeq": node_count
    }

    with open(args.output, "w") as f:
        json.dump(output, f, indent=4)
        f.write("\n")