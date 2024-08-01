# functions for transcoding to Parquet

import os

import pyarrow.csv as csv
import pyarrow.parquet as pq
import pyarrow as pa

from Bio import SeqIO


def csv_to_parquet(filename: str, read_options: csv.ReadOptions, parse_options: csv.ParseOptions, convert_options: csv.ConvertOptions) -> str:
    """
    Convert a single CSV file to a Parquet file using the supplied options

    Parameters
    ----------
        filename
            The path to the CSV file
        read_options
            PyArrow Read Options
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


def fasta_to_parquet(fasta_file: str, output: str):
    """
    Converts the provided FASTA file into a 2-column parquet file with columns
    ``seqid`` and ``sequence_length``

    Parameters
    ----------
        fasta_file
            path to the FASTA file
    
    Returns
    -------
        The filename of the new parquet files as ``fasta_file``.parquet
    """
    ids, lengths = [], []
    for record in SeqIO.parse(fasta_file, "fasta"):
        ids.append(record.id)
        lengths.append(len(record.seq))
    ids = pa.array(ids)
    lengths = pa.array(lengths)
    tbl = pa.Table.from_arrays([ids, lengths], names=["seqid", "sequence_length"])
    pq.write_table(tbl, output)