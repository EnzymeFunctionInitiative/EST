
import argparse
import os
import re
from cdhit import CdHitParser


def add_args(parser: argparse.ArgumentParser):
    """
    add arguments ``parser`` for computing clusters
    """
    parser.add_argument("--cdhit-file", required=True, type=str, help="The CD-HIT .clstr file to use for removing redundant sequences")
    parser.add_argument("--cluster-id-map", required=True, type=str, help="The input file that contains a sequence cluster ID to sequence ID mapping")
    parser.add_argument("--unique-cluster-id-map", required=True, type=str, help="The output file to store a filtered version of --cluster-id-map that excludes redundant sequences")
    parser.add_argument("--unique-sequence-ids", required=True, type=str, help="The output file to store a list of unique sequence IDs")


def check_arg_paths(args: argparse.Namespace):
    """
    Test file paths.
    """
    fail = False

    if not os.path.exists(args.cdhit_file):
        print(f"CD-HIT output file '{args.cdhit_file}' does not exist")
        fail = True

    if not os.path.exists(args.cluster_id_map):
        print(f"Input sequence cluster ID mapping file '{args.cluster_id_map}' does not exist")
        fail = True

    args.cdhit_file = os.path.abspath(args.cdhit_file)
    args.cluster_id_map = os.path.abspath(args.cluster_id_map)
    args.unique_cluster_id_map = os.path.abspath(args.unique_cluster_id_map)
    args.unique_sequence_ids = os.path.abspath(args.unique_sequence_ids)

    return args


def create_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Remove redundant sequences from an input FASTA file by using CD-HIT results")
    add_args(parser)
    return parser


def parse_cluster_ids(cluster_ids_file: str, unique_ids: dict) -> dict:
    """
    Parse a cluster ID mapping file into a dictionary that maps cluster
    number to a list of sequence IDs.  The file is either two or three
    columns and includes a header:

        node_label cluster_num_by_seq  cluster_num_by_node
        UNIPROTID1 1                   1
        ZZZ2       1                   1

    The output dictionary values contain a list that has one element if
    there are only two columns in the file, and contains a second
    element if there are three columns.  The second element is the
    cluster number, computed by number of nodes (not sequences).  The
    dictionary will only contain unique sequence IDs (as determined by
    the CD-HIT file).

    Parameters
    ----------
        cluster_ids_file
            path to a cluster ID mapping file
        unique_ids
            dictionary that maps sequence ID to 1; i.e. a list of unique
                sequence IDs

    Returns
    -------
        dictionary mapping cluster number to a one or two column array
    """

    cluster_ids = {}
    with open(cluster_ids_file, "r") as f:
        header_line = f.readline().strip()
        for line in f:
            parts = line.strip().split("\t")
            seq_id = parts[0]
            cluster_num = parts[1]
            if seq_id in unique_ids:
                # Save entire line for ease of writing later
                if not cluster_num in cluster_ids:
                    cluster_ids[cluster_num] = []
                cluster_ids[cluster_num].append(parts)

    return cluster_ids


def save_cluster_ids(cluster_id_map: dict, cluster_ids_file: str, sequence_ids_file: str):
    """
    Save a mapping of sequence cluster IDs to sequence IDs as well as a list
    of sequence IDs to output files.

    Parameters
    ----------
        cluster_id_map
            dict mapping SSN cluster number to unique accession IDs
        cluster_ids_file
            path to an output file that will store the mapping; equivalent
                in format to the input file parsed in 'parse_cluster_ids'
                (including a header)
        sequence_ids_file
            path to an output file that will store a list of sequence IDs
                (without a header)
    """

    map_fh = open(cluster_ids_file, "w")
    id_fh = open(sequence_ids_file, "w")

    map_fh.write("node_label\tcluster_num_by_seq\tcluster_num_by_node\n")

    for cluster_num, seq_ids in cluster_id_map.items():
        for seq_id_info in seq_ids:
            line = "\t".join(seq_id_info)
            map_fh.write(f"{line}\n")
            id_fh.write(f"{seq_id[1]}\n")

    id_fh.close()
    map_fh.close()




if __name__ == "__main__":
    args = check_arg_paths(create_arg_parser().parse_args())

    # Parse the CD-HIT .clstr file
    parser = CdHitParser(args.cdhit_file)

    # List of IDs that are unique
    unique_ids = parser.get_first_members()

    # Get a mapping of sequence cluster IDs to sequence IDs, but use
    # the computed unique IDs to only include unique sequence IDs in
    # the mapping
    cluster_id_map = parse_cluster_ids(args.cluster_id_map, unique_ids)

    # Save a cluster ID mapping and list of unique sequences to files
    save_cluster_ids(cluster_id_map, args.unique_cluster_id_map, args.unique_sequence_ids)

