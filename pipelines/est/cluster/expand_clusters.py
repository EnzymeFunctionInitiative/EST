import sys
import argparse
import re

def parse_cdhit_clstr(clstr_path):
    """
    Parses a CD-HIT .clstr file to map representative IDs to their list of children.
    Returns a dictionary: {representative_id: [child_id_1, child_id_2, ...]}
    """
    clusters = {}
    current_rep = None
    buffer_children = []
    
    # Regex to extract ID between '>' and '...'
    # Example: 0	200aa, >SeqID... *
    id_pattern = re.compile(r">(.*?)\.\.\.")

    with open(clstr_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith(">Cluster"):
                # If we have a previous cluster buffered, assign it to its rep
                if current_rep and buffer_children:
                    clusters[current_rep] = buffer_children
                
                # Reset for new cluster
                current_rep = None
                buffer_children = []
            else:
                # Parse sequence line
                match = id_pattern.search(line)
                if match:
                    seq_id = match.group(1)
                    buffer_children.append(seq_id)
                    # Check if this is the representative (ends with *)
                    if line.endswith('*'):
                        current_rep = seq_id

        # Catch the last cluster
        if current_rep and buffer_children:
            clusters[current_rep] = buffer_children
            
    return clusters

def expand_edges(blastin_path, blastout_path, clusters):
    """
    Reads BLAST file, looks up children for query/subject, and expands edges.
    """
    with open(blastin_path, 'r') as fin, open(blastout_path, 'w') as fout:
        for line in fin:
            parts = line.strip().split()
            if not parts: 
                continue
                
            query_rep = parts[0]
            subject_rep = parts[1]
            # Keep the rest of the BLAST columns (pident, evalue, etc.)
            rest_of_line = parts[2:] 

            # Validation
            if query_rep not in clusters:
                print(f"SOURCE {query_rep} does not exist in the cluster file", file=sys.stderr)
                continue
            
            query_children = clusters[query_rep]
            
            # CASE A: Self-Hit (Cluster hits itself)
            # This creates the internal clique (A-B, A-C, B-C) but excludes self-loops (A-A).
            if query_rep == subject_rep:
                n = len(query_children)
                for i in range(n):
                    for j in range(i + 1, n):
                        child_q = query_children[i]
                        child_s = query_children[j]
                        # Join and write
                        out_line = "\t".join([child_q, child_s] + rest_of_line)
                        fout.write(out_line + "\n")

            # CASE B: Cross-Hit (Cluster A hits Cluster B)
            else:
                if subject_rep not in clusters:
                    print(f"TARGET {subject_rep} does not exist in the cluster file", file=sys.stderr)
                    continue

                subject_children = clusters[subject_rep]
                
                for child_q in query_children:
                    for child_s in subject_children:
                        out_line = "\t".join([child_q, child_s] + rest_of_line)
                        fout.write(out_line + "\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Expand BLAST results based on CD-HIT clusters.")
    parser.add_argument("--cd-hit-cluster", required=True, help="CD-HIT .clstr file")
    parser.add_argument("--collapsed-blast", required=True, help="Input collapsed BLAST file")
    parser.add_argument("--expanded-blast", required=True, help="Output expanded BLAST file")
    
    args = parser.parse_args()
    
    print("Reading clusters...")
    cluster_map = parse_cdhit_clstr(args.cd_hit_cluster)
    
    print("Expanding edges...")
    expand_edges(args.collapsed_blast, args.expanded_blast, cluster_map)
    print("Done.")
