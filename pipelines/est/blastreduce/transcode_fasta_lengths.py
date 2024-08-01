import argparse
import os

from pyEFI.transcode import fasta_to_parquet

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

if __name__ == '__main__':
    args = check_args(create_parser().parse_args())
    print(fasta_to_parquet(args.fasta, args.output))