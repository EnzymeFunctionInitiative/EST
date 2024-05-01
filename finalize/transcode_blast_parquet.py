"""
Transcode BLAST paquet file back to CSV for perl-based SSN generation
"""

import argparse
import os

import csv
import pyarrow.parquet as pq
import pyarrow as pa


def parse_args():
    parser = argparse.ArgumentParser(description="Transcode BLAST output files and FASTA sequence lengths to Parquet")
    parser.add_argument("--blast-parquet", type=str, help="Path to directory containing the BLAST output files")

    args = parser.parse_args()

    # validate input filepath
    if not os.path.exists(args.blast_parquet):
        print(f"BLAST output '{args.blast_parquet}' does not exist")
        exit(1)
    else:
        return args

def parquet_to_csv_file(blast_filename: str, csv_filename: str):
    """
    Convert a single BLAST output parquet file to a CSV file

    Parameters
    ----------
        filename
            The path to the parquet file
    
    Returns
    -------
        A ParquetFile object representing the transcoded input file. Name will be `filename`.parquet
    """

    pqf = pq.ParquetFile(blast_filename)
    with open(csv_filename, "w") as f:
        fieldnames = [
            "qseqid",
            "sseqid",
            "pident",
            "alignment_length",
            "bitscore",
            "query_length",
            "subject_length",
            "alignment_score"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        
        for batch in pqf.iter_batches():
            for row in batch.to_pylist():
                row['pident'] = f"{row['pident']: .2f}"
                writer.writerow(row)



if __name__ == "__main__":
    args = parse_args()
    parquet_to_csv_file(args.blast_parquet, '1.out')
