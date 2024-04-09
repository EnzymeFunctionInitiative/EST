import argparse

import pyarrow as pa
import pyarrow.parquet as pq
from Bio import SeqIO

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fasta")
    parser.add_argument("--output")
    return parser.parse_args()

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
    args = parse_args()
    print(fasta_to_parquet(args.fasta, args.output))