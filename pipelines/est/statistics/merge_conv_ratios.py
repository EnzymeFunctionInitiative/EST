
import argparse
import json
import glob
import sys
import os
import math
import re

def main():
    parser = argparse.ArgumentParser(
        description="Merge individual convergence ratio JSON files into a single tab-separated file."
    )
    
    parser.add_argument(
        '--output', 
        required=True, 
        help="Path to the output .tab file"
    )
    parser.add_argument(
        '--stats', 
        nargs='*', 
        help="List of input JSON files. If not provided, globs *_conv_ratio.json in the current directory."
    )
    
    args = parser.parse_args()

    input_files = args.stats if args.stats else glob.glob('*_conv_ratio.json')
    
    if not input_files:
        print("Warning: No input JSON files found.", file=sys.stderr)
        
    # Read all data into a dictionary first
    data_dict = {}
    for json_file in input_files:
        filename = os.path.basename(json_file)
        
        # Extract the cluster number
        match = re.search(r'[cC]luster_(\d+)_conv_ratio\.json', filename)
        if match:
            cluster_id = match.group(1)
        else:
            cluster_id = filename.replace('_conv_ratio.json', '')
        
        try:
            with open(json_file, 'r') as f_in:
                data = json.load(f_in)
                
                ratio_val = data.get('convergence_ratio', 'NA')
                edges_val = data.get('num_blast_edges', 'NA')
                nodes_val = data.get('num_unique_ids', 'NA')
                
                if ratio_val != 'NA':
                    ratio_val = float(ratio_val)
                    
                data_dict[cluster_id] = {
                    'ratio': ratio_val,
                    'edges': edges_val,
                    'nodes': nodes_val
                }
        except Exception as e:
            print(f"Error processing file {json_file}: {e}", file=sys.stderr)

    # Calculate global min, max, and formatting digits
    # Extract only the valid floats from our nested dictionaries
    valid_ratios = [v['ratio'] for v in data_dict.values() if isinstance(v['ratio'], float)]
    
    digits = 2
    if valid_ratios:
        max_val = max(valid_ratios)
        min_val = min(valid_ratios)
        diff = max_val - min_val
        
        if diff > 1e10:
            digits = -int(math.log(diff) - 0.5) + 2
            
        digits = max(0, digits)
    
    # Output the data to a tab-separated file
    try:
        with open(args.output, 'w') as f_out:
            f_out.write("\t".join(["Cluster Number", "Convergence Ratio", "Number of IDs", "Number of BLAST Matches", "SSN Cluster Convergence Ratio", "Number of Nodes", "Number of Edges"]) + "\n")

            # Iterate through the dictionary and write the formatted rows
            for cluster_id, metrics in data_dict.items():
                ratio_val = metrics['ratio']
                edges_val = metrics['edges']
                nodes_val = metrics['nodes']
                
                if isinstance(ratio_val, float):
                    formatted_ratio = f"{ratio_val:.{digits}e}"
                else:
                    formatted_ratio = str(ratio_val)
                    
                # Write all four columns separated by tabs
                f_out.write("\t".join([cluster_id, formatted_ratio, str(edges_val), str(nodes_val), ]) + "\n")
                
    except IOError as e:
        print(f"Error writing to output file {args.output}: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
