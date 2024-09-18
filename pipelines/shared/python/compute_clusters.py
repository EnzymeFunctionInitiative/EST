
import os
import sys
import argparse
from network import SsnNetworkGraph




def add_args(parser: argparse.ArgumentParser):
    """
    add arguments ``parser`` for computing clusters
    """
    parser.add_argument("--edgelist", required=True, type=str, help="The edgelist file to compute on")
    parser.add_argument("--index-seqid-map", required=True, type=str, help="The file containing a mapping of edgelist node indices (col 1) to node sequence ID (col 2) and node size (col 3; for UniRef/repnode)")
    parser.add_argument("--clusters", required=True, type=str, help="The output file to store node sequence ID (col 1) to cluster num (col 2 by seq, col 3 by seq)")
    parser.add_argument("--cluster-info", required=True, type=str, help="The output file to store cluster size information in")


def check_args(args: argparse.Namespace) -> argparse.Namespace:
    """
    Test file paths and rewrite them to be absolute
    """
    fail = False

    if not os.path.exists(args.edgelist):
        print(f"Edgelist file '{args.edgelist}' does not exist")
        fail = True

    if not os.path.exists(args.index_seqid_map):
        print(f"Index-sequence ID mapping file '{args.index_seqid_map}' does not exist")
        fail = True

    args.edgelist = os.path.abspath(args.edgelist)
    args.index_seqid_map = os.path.abspath(args.index_seqid_map)
    args.clusters = os.path.abspath(args.clusters)
    args.cluster_info = os.path.abspath(args.cluster_info)

    return args


def create_parser():
    parser = argparse.ArgumentParser(description="Compute clusters from a SSN edgelist")
    add_args(parser)
    return parser


def get_node_id_mapping(id_map_file):

    idx_seqid_map = dict()
    idx_node_size = dict()

    with open(id_map_file) as fh:
        header = fh.readline()
        for line in fh:
            parts = line.rstrip().split("\t")
            if len(parts) >= 2:
                idx = int(parts[0])
                idx_seqid_map[idx] = parts[1]
                idx_node_size[idx] = int(parts[2]) if len(parts) >= 3 and parts[2] else 1

    return idx_seqid_map, idx_node_size




if __name__ == "__main__":
    args = check_args(create_parser().parse_args())

    idx_seqid_map, idx_size_map = get_node_id_mapping(args.index_seqid_map)

    net_graph = SsnNetworkGraph(idx_seqid_map, idx_size_map)
    net_graph.load_from_edgelist(args.edgelist)
    net_graph.compute_clusters()
    net_graph.save_clusters(args.clusters)
    net_graph.save_cluster_info(args.cluster_info)



