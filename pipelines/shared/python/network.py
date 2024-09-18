
import igraph


class SsnNetworkGraph:
    """
    Utility class for working with the SSN network graph (the mathematical graph, not visual) and edgelist.
    An edgelist is an array of length N, where each element of the array is another array of size two.
    The second array corresponds to the node indices of an edge.
    The node indices have been numbered in the order in which they occur in the file, starting at zero.
    """

    def __init__(self, idx_label_map, idx_size_map):
        """
        Create an object

        Parameters
        ----------
            idx_label_map
                a map of node indices to node labels (e.g. sequence IDs)
            idx_size_map
                a map of node indices to node size (e.g. UniRef/repnode)
        """
        self.idx_label_map = idx_label_map
        self.idx_size_map = idx_size_map


    def load_from_edgelist(self, edgelist_file):
        """
        Load the edgelist into an igraph Graph

        Parameters
        ----------
            edgelist_file
                path to a file containing the edgelist
        """
        self.G = igraph.Graph.Read_Edgelist(edgelist_file, directed = False)


    def compute_clusters(self):
        """
        Compute the clusters in the network; these are weakly-connected components as determined by igraph
        """
        # Use igraph to cluster the nodes
        self.components = self.G.connected_components(mode='weak')

        # Calculate the cluster sizes by two different metrics (number of nodes and number of sequences)
        self.cluster_size_by_node, self.cluster_size_by_seq = self.compute_cluster_sizes()

        # Sort by cluster node size and then assign a cluster number to each node, with the numbering
        # done according to the number of nodes in the cluster
        self.cluster_num_by_node, self.cluster_num_map_by_node = self.compute_cluster_numbers(self.cluster_size_by_node)

        # Sort by cluster sequence size and then assign a cluster number to each node, with the numbering
        # done according to the number of sequences in the cluster (e.g. accounting for UniRef/repnodes)
        self.cluster_num_by_seq, self.cluster_num_map_by_seq = self.compute_cluster_numbers(self.cluster_size_by_seq)


    def compute_cluster_sizes(self):
        """
        Compute the sizes of the clusters in network by number of nodes and number of sequences

        Returns
        -------
            cluster size by number of nodes in the cluster
            cluster size by number of sequences in the cluster
        """
        # This is a mapping of node index to cluster sizes computed by number of nodes in the cluster
        cluster_size_by_node = {}
        # This is a mapping of node index to cluster sizes computed by number of sequences in the cluster
        cluster_size_by_seq = {}

        # Loop over every cluster (e.g. component) and assign cluster numbers to the nodes (by number of nodes in cluster)
        cluster_idx = 0
        for comp_list in self.components:
            # Find the expanded (e.g. UniRef/repnodes) size of the cluster
            size_by_seq = 0
            for node_idx in comp_list:
                # Save the info for the size of the cluster by number of sequences
                num_seqs_in_node = self.idx_size_map.get(node_idx, 1)
                size_by_seq += num_seqs_in_node
            size_by_node = len(comp_list)
            # Save the expanded size (e.g. accounting for UniRef/repnodes) of the cluster
            cluster_size_by_seq[cluster_idx] = size_by_seq
            cluster_size_by_node[cluster_idx] = size_by_node
            cluster_idx += 1

        return cluster_size_by_node, cluster_size_by_seq


    def compute_cluster_numbers(self, cluster_sizes):
        """
        Create cluster numbers based on the sizes in the input dict

        Parameters
        ----------
            cluster_sizes
                mapping of cluster index (from self.components) to size (based on a metric)

        Returns
        -------
            dict mapping node index to cluster number
        """
        # Order by cluster size
        cluster_size_order = dict(sorted(cluster_sizes.items(), key=lambda item: item[1], reverse=True))
        cluster_idx = 0
        node_cluster = {}
        cluster_num_map = {} # Map the old numbering (e.g. index into self.components) to the new numbering
        # Assign numbers; idx is the old (self.components) index, but the dict is sorted based on the value (cluster size)
        for idx in cluster_size_order:
            for node_idx in self.components[idx]:
                node_cluster[node_idx] = cluster_idx + 1
            cluster_num_map[idx] = cluster_idx + 1
            cluster_idx += 1
        return node_cluster, cluster_num_map

    
    def save_cluster_info(self, info_file):
        """
        Save the cluster size information to a file, formatted as
        "cluster_num_by_seq\tcluster_size_by_seq\tcluster_num_by_node\tcluster_size_by_node"

        Parameters
        ----------
            info_file
                path to a file to output cluster info to
        """
        with open(info_file, "w") as fh:
            fh.write("cluster_num_by_seq\tcluster_size_by_seq\tcluster_num_by_node\tcluster_size_by_node\n")
            # The dict index here represents the old (self.components) cluster number; sorting
            # in the file will be done by sequence number
            for idx in self.cluster_num_map_by_seq:
                cluster_num_seq = self.cluster_num_map_by_seq[idx]
                cluster_num_node = self.cluster_num_map_by_node[idx]
                cluster_size_seq = self.cluster_size_by_seq[idx]
                cluster_size_node = self.cluster_size_by_node[idx]
                fh.write(f"{cluster_num_seq}\t{cluster_size_seq}\t{cluster_num_node}\t{cluster_size_node}\n");


    def save_clusters(self, cluster_file):
        """
        Save the cluster connectivity (connected components) to a file, formatted as
        "node_label\tcluster_num_by_node\tcluster_num_by_seq"

        Parameters
        ----------
            cluster_file
                path to a file to output cluster connectivity to
        """
        with open(cluster_file, "w") as fh:
            i = 1
            fh.write("node_label\tcluster_num_by_node\tcluster_num_by_seq\n")
            for comp_list in self.components:
                for node_idx in comp_list:
                    label_id = self.idx_label_map.get(node_idx, "")
                    cnum_node = self.cluster_num_by_node[node_idx]
                    cnum_seq = self.cluster_num_by_seq[node_idx]
                    fh.write(f"{label_id}\t{cnum_node}\t{cnum_seq}\n")
                i = i + 1


