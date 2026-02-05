
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

def parse_accession_table(accession_table: str, seq_type: str) -> Set[str]:
    """
    Parses a three-column accession table file and gets the list of sequences that correspond
    to the given sequence type (e.g. uniprot, uniref90, uniref50).  The table file has a header
    column.
    """
    ids = set()
    col_map = {'uniprot': 0, 'uniref90': 1, 'uniref50': 2}
    target_col = col_map[seq_type]

    try:
        with open(accession_table, 'r') as fh:
            next(fh)
            for line in fh:
                parts = line.strip().split('\t')
                if len(parts) < 3:
                    continue
                
                uniprot_id = parts[0]
                
                # For 'uniprot' type, we consider all IDs in the first column.
                if seq_type == 'uniprot':
                    ids.add(uniprot_id)
                # For 'uniref' types, we only add the UniProt ID if the corresponding
                # UniRef column is not empty.
                elif parts[target_col]:
                    ids.add(uniprot_id)

    except FileNotFoundError:
        print(f"Error: Accession table file not found at '{accession_table}'", file=sys.stderr)
        sys.exit(1)

    return ids

def compute_sequence_lengths(fasta_file: str, valid_ids: Set[str]) -> List[int]:
    """
    Process the FASTA file and collect lengths
    """
    sequence_lengths = []
    try:
        with open(fasta_file, 'r') as fh:
            for header, sequence in parse_fasta(fh):
                include_sequence = False

                # Include the sequence if it starts with 'ZZ' (no UniProt match was found for the header)
                if header.startswith('ZZ'):
                    include_sequence = True
                
                # Include if the UniProt ID is in our set of valid IDs.
                elif header in valid_ids:
                    include_sequence = True

                if include_sequence:
                    sequence_lengths.append(len(sequence))

    except FileNotFoundError:
        print(f"Error: FASTA file not found at '{fasta_file}'", file=sys.stderr)
        sys.exit(1)

    return sequence_lengths

def main(fasta_file: str, accession_table: str, seq_type: str, output_file: str):
    """
    Computes a length histogram for sequences based on specified criteria.
    """
    if seq_type not in ['uniprot', 'uniref90', 'uniref50']:
        print(f"Error: Invalid sequence type '{seq_type}'. Must be one of 'uniprot', 'uniref90', 'uniref50'.", file=sys.stderr)
        sys.exit(1)

    valid_ids = parse_accession_table(accession_table, seq_type)

    sequence_lengths = compute_sequence_lengths(fasta_file, valid_ids)

    if not sequence_lengths:
        print(f"Warning: No sequences were selected for histogram generation for type '{seq_type}'. Output will be empty.", file=sys.stderr)

    length_counts = Counter(sequence_lengths)

    with open(output_file, 'w') as f_out:
        f_out.write("length\tcount\n")
        # Sort by length for a clean output file
        for length, count in sorted(length_counts.items()):
            f_out.write(f"{length}\t{count}\n")
    
    print(f"Successfully wrote histogram for '{seq_type}' to '{output_file}'")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Compute a length histogram for sequences in a FASTA file.")
    parser.add_argument('--fasta-file', required=True, help="Path to the input FASTA file.")
    parser.add_argument('--accession-table', required=True, help="Path to the 3-column accession table file.")
    parser.add_argument('--seq-type', required=True, choices=['uniprot', 'uniref90', 'uniref50'], help="The sequence type to generate the histogram for.")
    parser.add_argument('--output-file', required=True, help="Path to write the output histogram file.")
    
    args = parser.parse_args()
    
    main(args.fasta_file, args.accession_table, args.seq_type, args.output_file)

