import argparse
import json
import math
import os

import pyarrow.parquet as pq

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

def compute_conv_ratio(blast_output: str, fasta_file: str) -> tuple[float, int, int]:
    """
    Compute the convergence ratio of the full network

    Parameters
    ----------
        blast_output
            The transcoded BLAST output file path

        fasta_file
            The transcoded FASTA file path

    Returns
    -------
        A tuple. The first value is the convergence ratio, the second is the
        number of nodes (sequences) and the third is the number of edges
    """
    edge_count = pq.ParquetFile(blast_output).metadata.num_rows
    node_count = pq.ParquetFile(fasta_file).metadata.num_rows
    num = edge_count * 2.0
    nom = float(math.floor(node_count * (node_count - 1)))
    if nom != 0:
        conv_ratio =  num / nom
    else:
        conv_ratio = 0
    return conv_ratio, node_count, edge_count


if __name__ == "__main__":
    args = check_args(create_parser().parse_args())
    conv_ratio, node_count, edge_count = compute_conv_ratio(args.blast_output, args.fasta)
    output = {
        "ConvergenceRatio": conv_ratio,
        "EdgeCount": edge_count,
        "UniqueSeq": node_count
    }

    with open(args.output, "w") as f:
        json.dump(output, f, indent=4)
        f.write("\n")