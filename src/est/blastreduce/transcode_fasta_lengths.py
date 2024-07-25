import argparse
import os

import pyarrow as pa
import pyarrow.parquet as pq
from Bio import SeqIO

def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fasta", type=str, required=True, help="The FASTA file to transcode")
    parser.add_argument("--output", type=str, required=True, help="Output filename for trancoded FASTA")
    return parser

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    fail = False
    if not os.path.exists(args.fasta):
        print(f"FASTA file '{args.fasta}' does not exist")
        fail = True

    if fail:
        exit(1)
    else:
        args.fasta = os.path.abspath(args.fasta)
        return args

def fasta_to_parquet(fasta_file: str, output: str):
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
    pq.write_table(tbl, output)

if __name__ == '__main__':
    args = check_args(create_parser().parse_args())
    print(fasta_to_parquet(args.fasta, args.output))