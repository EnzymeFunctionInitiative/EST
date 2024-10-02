
Compute Clusters
================

Clusters are computed based on node connectivity using igraph. The input is a simple
edgelist file for performance reasons (i.e. the graph isn't constructed on the
fly as a file is parsed). An edgelist is an array of length N, where each
element of the array is another array of size two. Each value is a node index,
starting at zero and ordered in the way the nodes appear in the SSN.

    usage: compute_clusters.py [-h] --edgelist EDGELIST --index-seqid-map INDEX_SEQID_MAP --clusters CLUSTERS --singletons SINGLETONS --cluster-num-map CLUSTER_NUM_MAP
    
    Compute clusters from a SSN edgelist
    
    options:
      -h, --help            show this help message and exit
      --edgelist EDGELIST   The edgelist file to compute on
      --index-seqid-map INDEX_SEQID_MAP
                            The file containing a mapping of edgelist node indices (col 1)
                            to node sequence ID (col 2) and node size (col 3; for UniRef/repnode)
      --clusters CLUSTERS   The output file to store node sequence ID (col 1) to cluster num
                            (col 2 by seq, col 3 by seq)
      --singletons SINGLETONS
                            The output file to store singletons (clusters with only one sequence) in
      --cluster-num-map CLUSTER_NUM_MAP
                            path to an output file containing a mapping of cluster number based on
                            sequences to number based on nodes

