
import argparse
from collections import Counter
import sys
from typing import Iterator, Tuple, TextIO, Set, List

def parse_fasta(file_handle: TextIO) -> Iterator[Tuple[str, str]]:
    """
    A simple FASTA parser that yields tuples of (header, sequence).
    """
    header = None
    sequence = []
    for line in file_handle:
        line = line.strip()
        if not line:
            continue
        if line.startswith('>'):
            if header:
                yield (header, ''.join(sequence))
            header = line[1:].split()[0] # Get the ID before any spaces
            sequence = []
        else:
            sequence.append(line)
    if header:
        yield (header, ''.join(sequence))

def parse_file(input_file: str, target_col: int, has_header_line: bool = True) -> Set[str]:
    """
    Parses a file and extracts IDs from the given column index. The file can have an optional header column.
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
    Parses a standard three-column accession table file output by the 'est' pipeline, and gets
    the list of sequences that correspond to the given sequence type (e.g. uniprot, uniref90,
    uniref50). The table file has a header column.
    """
    col_map = {'uniprot': 0, 'uniref90': 1, 'uniref50': 2}
    target_col = col_map[seq_type]

    return parse_file(accession_table, target_col, True)

def compute_sequence_lengths(fasta_file: str, valid_ids: Set[str] = None) -> List[int]:
    """
    Process the FASTA file and collect lengths. If 'valid_ids' is a Set, then only sequences
    with IDs in the Set are included in the output. If 'valid_ids' is None, then all
    sequences are included.
    """
    sequence_lengths = []
    try:
        with open(fasta_file, 'r') as fh:
            for header, sequence in parse_fasta(fh):
                include_sequence = False

                # Include the sequence if it starts with 'ZZ' (e.g. the input to the EST pipeline
                # was a FASTA file that didn't have UniProt IDs in the header).
                if header.startswith('ZZ'):
                    include_sequence = True
                
                # Include if the ID is in our set of valid IDs.
                elif valid_ids == None or header in valid_ids:
                    include_sequence = True

                if include_sequence:
                    sequence_lengths.append(len(sequence))

    except FileNotFoundError:
        print(f"Error: FASTA file not found at '{fasta_file}'", file=sys.stderr)
        sys.exit(1)

    return sequence_lengths

def compute_histogram(fasta_file: str, output_file: str, accession_table: str = None, seq_type: str = None):
    """
    Computes a length histogram for sequences. If an 'accession_table' file is provided, that file
    is parsed to obtain a list of IDs to use for generating the length histogram.
    """

    # For a log message
    seq_type_str = f" for type '{seq_type}'" if seq_type else ""

    # None == use all sequences in fasta
    if accession_table and seq_type:
        valid_ids = parse_accession_table(accession_table, seq_type)
    else:
        valid_ids = None

    sequence_lengths = compute_sequence_lengths(fasta_file, valid_ids)

    if not sequence_lengths:
        print(f"Warning: No sequences were selected for histogram generation{seq_type_str}. Output will be empty.", file=sys.stderr)

    length_counts = Counter(sequence_lengths)

    with open(output_file, 'w') as f_out:
        f_out.write("length\tcount\n")
        # Sort by length for a clean output file
        for length, count in sorted(length_counts.items()):
            f_out.write(f"{length}\t{count}\n")
    
    print(f"Successfully wrote histogram{seq_type_str} to '{output_file}'")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Compute a length histogram for sequences in a FASTA file.")
    parser.add_argument('--fasta-file', required=True, help="Path to the input FASTA file.")
    parser.add_argument('--output-file', required=True, help="Path to write the output histogram file.")
    parser.add_argument('--accession-table', required=False, help="Path to accession table file, containing three columns (uniprot, uniref90, uniref50).  If not specified, then all of the sequences in the FASTA file are used in the length histogram computation.")
    parser.add_argument('--seq-type', required=False, choices=['uniprot', 'uniref90', 'uniref50'], help="The sequence type to generate the histogram for; choosing 'uniprot' is equivalent to choosing the first column.")

    args = parser.parse_args()
    
    compute_histogram(args.fasta_file, args.output_file, args.accession_table, args.seq_type)
