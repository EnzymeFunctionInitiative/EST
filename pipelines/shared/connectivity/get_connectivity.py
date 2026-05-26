import argparse
import collections
import matplotlib as mpl
import matplotlib.pyplot as plt
import os
from pyEFI.nb_conn_colormap import get_nb_conn_colormap
import re
import sys
from typing import Any, Dict, List, Optional, Set, Tuple

def get_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Calculate Neighborhood Connectivity and map to colors.")
    parser.add_argument("--input-blast", type=str, help="Input blast (TSV) file")
    parser.add_argument("--input-xgmml", type=str, help="Input XGMML file")
    parser.add_argument("--output-map", type=str, required=True, help="Output map file")
    parser.add_argument("--include-meta", action="store_true", help="Include min/max meta row")
    parser.add_argument("--cdhit", type=str, help="CD-HIT cluster file to filter by")
    parser.add_argument("--matplotlib-colormap", type=str, help="The type of colorbar to use (acceptable values are ones supported by matplotlib color maps, e.g.  'viridis', 'jet', 'coolwarm', etc.). If not specified, a custom internal one is used")

    args = parser.parse_args()

    # File validation
    if not args.input_blast and not args.input_xgmml:
        sys.exit("Error: Need --input-blast blast file OR --input-xgmml xgmml")

    return args

def get_cdhit_clusters(file_path: str) -> Set[str]:
    """
    Parses the CD-HIT output and returns a set of representative sequence IDs.

    Parameters
    ----------
        file_path
            Path to the CD-HIT .clstr file

    Returns
    -------
        Set containing representative cluster IDs
    """

    filter_ids = set()

    # Capture sequence ID for representative sequence
    id_pattern = re.compile(r'>([^\s\.]+)\.\.\.\s+\*')

    with open(file_path, 'r') as fh:
        for line in fh:
            if line.rstrip().endswith('*'):
                id_match = id_pattern.search(line)
                if id_match:
                    filter_ids.add(id_match.group(1))

    return filter_ids

def parse_blast_line(line: str, filter_ids: Set[str], use_cdhit: bool) -> Tuple[Optional[str], Optional[str]]:
    """
    Extracts source and target from a TSV BLAST file line.

    Parameters
    ----------
        line
            Current line in the BLAST file that is being parsed
        filter_ids
            Set of cluster IDs in a cd-hit file
        use_cdhit
            If true, only return the IDs if the source and target IDs are present in input
            filter_ids; if false, return any valid source and target IDs

    Returns
    -------
        Tuple containing source and target IDs; [None, None] if not in filter_ids or not valid line
    """
    parts = line.strip('\r\n').split('\t')
    if len(parts) >= 2:
        source, target = parts[0], parts[1]
        # Only return nodes that exist in our CD-HIT clusters (if provided)
        if not use_cdhit or (source in filter_ids and target in filter_ids):
            return source, target
    return None, None

def parse_xgmml_line(line: str) -> Tuple[Optional[str], Optional[str]]:
    """
    Extracts source and target from an XGMML edge line using Regex.

    Parameters
    ----------
        line
            Line from XGMML file

    Returns
    -------
        Tuple containing source and target IDs from an edge; returns [None, None] if not an edge
    """
    if "<edge" not in line:
        return None, None

    # Try parsing Cytoscape label formatting
    m = re.search(r'label="([^"]+),([^"]+)"', line)
    if m:
        return m.group(1), m.group(2)

    # Fallback to direct source/target attributes
    m_source = re.search(r'source="([^"]+)"', line)
    m_target = re.search(r'target="([^"]+)"', line)
    if m_source and m_target:
        return m_source.group(1), m_target.group(1)

    return None, None

def parse_input(args: argparse.Namespace) -> Dict[str, List[str]]:
    """
    Parse the input file (either BLAST or XGMML) and save degrees of each node.

    Parameters
    ----------
        args
            argparse Namespace containing input parameters and file paths

    Returns
    -------
        Dictionary of neighbor list
    """

    filter_ids = set()
    use_cdhit = False

    if args.cdhit and os.path.isfile(args.cdhit):
        filter_ids = get_cdhit_clusters(args.cdhit)
        use_cdhit = True

    # Graph data structures
    neighbors = collections.defaultdict(list)

    # Determine input type, either a BLAST file or a XGMML file, and create a callback to
    # handle parsing the line
    if args.input_blast:
        in_file = args.input_blast
        parse_fn = lambda l: parse_blast_line(l, filter_ids, use_cdhit)
    else:
        in_file = args.input_xgmml
        parse_fn = parse_xgmml_line

    # Build the graph
    with open(in_file, 'r') as f:
        for line in f:
            source, target = parse_fn(line)
            if not source:
                continue
            neighbors[source].append(target)
            neighbors[target].append(source)

    # Ensure all CD-HIT cluster reps are present (even those with a degree of 0)
    if use_cdhit:
        for nid in filter_ids:
            if nid not in neighbors:
                neighbors[nid] = []

    return neighbors

def compute_connectivity(neighbors: Dict[str, List[str]]) -> Tuple[float, float, Dict[str, Any]]:
    """
    Compute neighborhood connectivity.

    Parameters
    ----------
        neighbors
            Dictionary of neighborhood data

    Returns
    -------
        min_nc
            Minimum neighborhood connectivity
        max_nc
            Maximum neighborhood connectivity
        NC
            Neighborhood connectivity mapping
    """
    NC = {}
    max_nc = 0
    min_nc = float('inf')

    # Calculate Neighborhood Connectivity
    for nid, nb_list in neighbors.items():
        k = len(nb_list)
        nc_sum = sum(len(neighbors[n]) for n in nb_list)

        # Compute factor and convert to percentage
        val = (nc_sum * 100) / k if k > 0 else 0.0

        NC[nid] = {'nc': val}

        min_nc = min(min_nc, val)
        max_nc = max(max_nc, val)

    # Handle empty graph fallbacks smoothly
    if min_nc > max_nc:
        min_nc = 0
        max_nc = 0

    return min_nc, max_nc, NC

def save_table(args: argparse.Namespace, min_nc: float, max_nc: float, NC: Dict[str, Any]) -> None:
    """
    Save a table with connectivity and color for each node in the network.

    Parameters
    ----------
        args
            argparse Namespace containing input parameters and file paths
        min_nc
            Minimum neighborhood connectivity
        max_nc
            Maximum neighborhood connectivity
        NC
            Neighborhood connectivity mapping
    """

    # Initialize Matplotlib color mapping setup
    if args.matplotlib_colormap:
        # Use matplotlib standard
        cmap = plt.get_cmap(args.matplotlib_colormap)
    else:
        # Use custom EFI
        cmap = get_nb_conn_colormap()
    norm = mpl.colors.Normalize(vmin=min_nc, vmax=max_nc)

    # Generate colors based on NC value and attach to final dictionary
    for nid in NC:
        val = NC[nid]['nc']
        # Generates a standard Cytoscape-friendly hex string (e.g. #440154)
        NC[nid]['color'] = mpl.colors.to_hex(cmap(norm(val))).upper()

    # Write output map
    with open(args.output_map, 'w') as f:
        # Save a header line containing min and max
        if args.include_meta:
            f.write(f"_META\tmin\t{min_nc}\tmax\t{max_nc}\n")

        f.write("ID\tNC\tCOLOR\n")
        for nid in sorted(NC.keys()):
            f.write(f"{nid}\t{NC[nid]['nc']:.2f}\t{NC[nid]['color']}\n")

if __name__ == "__main__":
    args = get_args()
    neighbors = parse_input(args)
    min_nc, max_nc, NC = compute_connectivity(neighbors)
    save_table(args, min_nc, max_nc, NC)
