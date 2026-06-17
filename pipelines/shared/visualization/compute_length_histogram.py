
import argparse
from Bio.SeqIO.FastaIO import SimpleFastaParser
from collections import Counter
import re
import sys
from typing import Iterator, Tuple, TextIO, Set, List

def parse_file(input_file: str, target_col: int, has_header_line: bool = True) -> Set[str]:
    """
    Parse a file and extract IDs from the given column index.

    Parameters
    ----------
        input_file
            path to input ID list file
        target_col
            zero-based index of the column to obtain the IDs from (e.g. 0 for UniProt,
            1 for UniRef90, 2 for UniRef50)
        has_header_line
            true if the input file has headers

    Returns
    -------
        Set of sequence IDs (strings)
    """
    ids = set()

    try:
        with open(input_file, 'r') as fh:
            if has_header_line:
                next(fh)
            for line in fh:
                parts = line.split('\t')
                if len(parts) > target_col:
                    val = parts[target_col].strip()
                    if val:
                        ids.add(val)

    except FileNotFoundError:
        print(f"Error: input ID file not found at '{input_file}'", file=sys.stderr)
        sys.exit(1)

    return ids

def parse_accession_table(accession_table: str, seq_type: str) -> Set[str]:
    """
    Parse a standard three-column accession table file output by the 'est' pipeline, and get
    the list of sequences that correspond to the given sequence type (e.g. uniprot, uniref90,
    uniref50).  The table file has a header column.

    Parameters
    ----------
        accession_table
            path to the accession table file
        seq_type
            'uniprot', 'uniref90', or 'uniref50', depending on the desired column to retrieve

    Returns
    -------
        Set of sequence IDs (strings)
    """
    col_map = {'uniprot': 0, 'uniref90': 1, 'uniref50': 2}
    target_col = col_map[seq_type]

    return parse_file(accession_table, target_col, True)

def compute_sequence_lengths(fasta_file: str, valid_ids: Set[str] = None) -> List[int]:
    """
    Process a FASTA file and collect lengths.

    Parameters
    ----------
        fasta_file
            path to FASTA file containing sequences
        valid_ids
            Set of string IDs, or None; if None, then all sequences are included in the
            computation, otherwise only sequence IDs that are in the Set are included

    Returns
    -------
        List of sequence lengths, ordered by occurrence of sequence in the file
    """
    sequence_lengths = []
    try:
        with open(fasta_file, 'r') as fh:
            for title, sequence in SimpleFastaParser(fh):
                id_chunk = re.split(r'[ :]', title)[0]
                parsed_id = id_chunk.split('|')[1] if '|' in id_chunk else id_chunk

                include_sequence = False

                # Include the sequence if it starts with 'ZZ' (e.g. the input to the EST pipeline
                # was a FASTA file that didn't have UniProt IDs in the header) or 'ZINPUT' (the
                # EST pipeline was based of a BLAST input).
                if parsed_id.startswith(('ZZ', 'ZINPUT')):
                    include_sequence = True
                
                # Include if the ID is in our set of valid IDs.
                elif valid_ids == None or parsed_id in valid_ids:
                    include_sequence = True

                if include_sequence:
                    sequence_lengths.append(len(sequence))

    except FileNotFoundError:
        print(f"Error: FASTA file not found at '{fasta_file}'", file=sys.stderr)
        sys.exit(1)

    return sequence_lengths

def load_length_mapping(length_mapping_file: str, valid_ids: Set[str] = None) -> List[int]:
    """
    Process a length mapping file to collect lengths.

    Parameters
    ----------
        length_mapping_file
            path to a two-column tab-separated file containing sequence ID and sequence length
        valid_ids
            Set of string IDs, or None; if None, then all sequences are included in the
            computation, otherwise only sequence IDs that are in the Set are included

    Returns
    -------
        List of sequence lengths, ordered by occurrence of sequence in the file
    """
    sequence_lengths = []
    try:
        with open(length_mapping_file, 'r') as fh:
            for line in fh:
                parts = line.strip().split('\t')
                if valid_ids == None or parts[0] in valid_ids:
                    sequence_lengths.append(parts[1])

    except FileNotFoundError:
        print(f"Error: length mapping file not found at '{length_mapping_file}'", file=sys.stderr)
        sys.exit(1)

    return sequence_lengths

def get_sequence_lengths(accession_table: str, fasta_file: str, length_mapping_file: str, seq_type: str = None) -> List[int]:
    """
    Get the sequence lengths from the inputs.  If a FASTA file is specified, compute the lengths
    from the file.  If a length mapping file is specified, retrieve the lengths from the file.

    Parameters
    ----------
        accession_table
            path to accession table, or None; if provided, then this file is parsed to obtain a
            list of IDs to use for generating the length histogram
        fasta_file
            path to FASTA file containing sequences
        length_mapping_file
            path to a two-column tab-separated file containing sequence ID and sequence length
        seq_type
            sequence type to use for obtaining IDs when `accession_table` is provided

    Returns
    -------
        List of sequence lengths, ordered by occurrence of sequence in the file
    """

    # None == use all sequences in fasta
    if accession_table and seq_type:
        valid_ids = parse_accession_table(accession_table, seq_type)
    else:
        valid_ids = None

    if fasta_file:
        sequence_lengths = compute_sequence_lengths(fasta_file, valid_ids)
    elif length_mapping_file:
        sequence_lengths = load_length_mapping(length_mapping_file, valid_ids)

    return sequence_lengths

def compute_histogram(sequence_lengths: List[int], output_file: str, seq_type: str = None):
    """
    Compute a length histogram for sequences.  The output file contains a histogram, with each
    line containing the length of a sequence and the number of sequences with that length,
    ordered by sequence count.

    Parameters
    ----------
        sequence_lengths
            list of sequence lengths
        output_file
            path to output file containing histogram
        seq_type
            sequence type to use for obtaining IDs when `accession_table` is provided
    """

    # For a log message
    seq_type_str = f" for type '{seq_type}'" if seq_type else ""

    if not sequence_lengths:
        print(f"Warning: No sequences were selected for histogram generation{seq_type_str}. Output will be empty.", file=sys.stderr)

    length_counts = Counter(int(length) for length in sequence_lengths)

    with open(output_file, 'w') as f_out:
        f_out.write("length\tcount\n")
        # Sort by length for a clean output file
        for length, count in sorted(length_counts.items()):
            f_out.write(f"{length}\t{count}\n")
    
    print(f"Successfully wrote histogram{seq_type_str} to '{output_file}'")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Compute a length histogram for sequences in a FASTA file.")
    parser.add_argument('--fasta-file', required=False, help="Path to the input FASTA file.")
    parser.add_argument('--length-mapping-file', required=False, help="Path to the file mapping IDs to lengths.")
    parser.add_argument('--output-file', required=True, help="Path to write the output histogram file.")
    parser.add_argument('--accession-table', required=False, help="Path to accession table file, containing three columns (uniprot, uniref90, uniref50).  If not specified, then all of the sequences in the FASTA file are used in the length histogram computation.")
    parser.add_argument('--seq-type', required=False, choices=['uniprot', 'uniref90', 'uniref50'], help="The sequence type to generate the histogram for; choosing 'uniprot' is equivalent to choosing the first column.")

    args = parser.parse_args()

    if not args.fasta_file and not args.length_mapping_file:
        print(f"Error: require either --fasta-file or --length-mapping-file as input arguments; neither found", file=sys.stderr)
        sys.exit(1)

    sequence_lengths = get_sequence_lengths(args.accession_table, args.fasta_file, args.length_mapping_file, args.seq_type)

    compute_histogram(sequence_lengths, args.output_file, args.seq_type)
