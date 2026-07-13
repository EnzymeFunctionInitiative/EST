
import argparse
import glob
import json
import math
import os
import re
import sys
from typing import Any, Dict, List

def create_parser() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Merge individual convergence ratio JSON files into a single tab-separated file.")
    parser.add_argument('--ssn-conv-ratio', required=True, help="Path to the SSN cluster-based convergence ratio file from the colorssn shared workflow.")
    parser.add_argument('--output', required=True, help="Path to the output .tab file")
    parser.add_argument('--stats', nargs='*', help="List of input JSON files. If not provided, globs *_conv_ratio.json in the current directory.")
    return parser

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    if not args.stats:
        print("Warning: No input JSON files found.", file=sys.stderr)
        exit(1)
    return args

def load_blast_conv_files(input_files: List) -> Dict[int, Dict[str, str]]:
    """
    Load the BLAST-based convergence ratios from the given files.

    Parameters
    ----------
        input_files
            A list of paths to JSON files containing convergence ratio data, one per cluster

    Returns
    -------
        A dictionary of dictionaries, mapping cluster ID to data for that cluster
    """

    blast_data = {}
    for json_file in input_files:
        filename = os.path.basename(json_file)

        # Extract the cluster number
        match = re.search(r'Cluster_(\d+)_conv_ratio\.json', filename)
        if match:
            cluster_num = int(match.group(1))
        else:
            # Terminate because something bad happened, if the files aren't in the specified format
            raise Exception(f"Invalid filename format '{filename}'")

        conv_ratio = None
        edges = None
        nodes = None
        try:
            with open(json_file, 'r') as fh:
                data = json.load(fh)

                conv_ratio = data.get('convergence_ratio', None)
                edges = data.get('num_blast_edges', None)
                nodes = data.get('num_unique_ids', None)

                if conv_ratio != None:
                    conv_ratio = float(conv_ratio)
        except Exception as e:
            print(f"Error processing file {json_file}: {e}", file=sys.stderr)

        blast_data[cluster_num] = {
            'ratio': conv_ratio,
            'edges': edges,
            'nodes': nodes
        }

    return blast_data

def load_ssn_conv_data(data_file: str) -> Dict[int, Dict[str, str]]:
    """
    Load the convergence ratio data from the SSN-based table.

    Parameters
    ----------
        data_file
            Path to the SSN-based convergence ratio table file

    Returns
    -------
        A dictionary of dictionaries, mapping cluster ID to data for that cluster
    """

    ssn_data = {}
    try:
        with open(data_file, 'r') as fh:
            header = next(fh)

            for line in fh:
                cluster_num, conv_ratio, num_nodes, num_ids, num_edges = re.split(r'\t', line.strip())
                ssn_data[int(cluster_num)] = {
                    'ratio': conv_ratio,
                    'edges': num_edges,
                    'nodes': num_nodes,
                }

    except IOError as e:
        print(f"Error reading SSN convergence ratio data file {data_file}: {e}", file=sys.stderr)
        sys.exit(1)

    return ssn_data

def calc_sig_figs(blast_conv_data: Dict[int, Any]) -> int:
    """
    Compute the number of significant figures that are used for formatting.

    Parameters
    ----------
        blast_conv_data
            Dictionary of dictionaries, mapping cluster ID to data

    Returns
    -------
        Int, representing the number of digits to use when formatting the output convergence ratio
    """

    # Extract only the valid floats from our nested dictionaries
    valid_ratios = [v['ratio'] for v in blast_conv_data.values() if isinstance(v['ratio'], float)]

    digits = 2
    if valid_ratios:
        max_val = max(valid_ratios)
        min_val = min(valid_ratios)
        diff = max_val - min_val

        if diff > 1e10:
            digits = -int(math.log(diff) - 0.5) + 2

        digits = max(0, digits)

    return digits

def save_merged_data(output: str, blast_conv_data: Dict[int, Any], ssn_conv_data: Dict[int, Any], digits: int):
    """
    Merge the individual convergence ratio data into one file.

    Parameters
    ----------
        output
            Path to the output file
        blast_conv_data
            Dictionary of dictionaries, mapping cluster ID to BLAST-based data
        ssn_conv_data
            Dictionary of dictionaries, mapping cluster ID to SSN-based data
        digits:
            The number of digits to use when formatting the output convergence ratio
    """

    try:
        with open(output, 'w') as f_out:
            f_out.write("\t".join(["Cluster Number", "Convergence Ratio", "Number of IDs", "Number of BLAST Matches", "SSN Cluster Convergence Ratio", "Number of Nodes", "Number of Edges"]) + "\n")

            # Iterate through the dictionary and write the formatted rows
            for cluster_num, metrics in sorted(blast_conv_data.items()):
                blast_conv_ratio = metrics['ratio']
                blast_conv_ratio_fmt = f"{blast_conv_ratio:.{digits}e}" if isinstance(blast_conv_ratio, float) else str(blast_conv_ratio)

                ssn_metrics = ssn_conv_data.get(cluster_num)
                ssn_conv_ratio = ssn_metrics['ratio']
                ssn_conv_ratio_fmt = f"{ssn_conv_ratio:.{digits}e}" if isinstance(ssn_conv_ratio, float) else str(ssn_conv_ratio)

                # Write all four columns separated by tabs
                f_out.write("\t".join([str(cluster_num), blast_conv_ratio_fmt, str(metrics['nodes']), str(metrics['edges']), ssn_conv_ratio_fmt, str(ssn_metrics['nodes']), str(ssn_metrics['edges'])]) + "\n")

    except KeyError as e:
        print(f"Unable to find cluster ID {e.args[0]} in SSN convergence ratio data", file=sys.stderr)
        sys.exit(1)

    except IOError as e:
        print(f"Error writing to output file {output}: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    args = check_args(create_parser().parse_args())

    blast_conv_data = load_blast_conv_files(args.stats)

    ssn_conv_data = load_ssn_conv_data(args.ssn_conv_ratio)

    digits = calc_sig_figs(blast_conv_data)

    # Output the data to a tab-separated file
    save_merged_data(args.output, blast_conv_data, ssn_conv_data, digits)

