
import argparse
import json
import os

import pandas as pd
from pyEFI.processing import compute_outlying_groups, delete_outlying_groups


def create_parser():
    """Creates the command-line argument parser."""
    parser = argparse.ArgumentParser(
        description="Generate Plotly-compatible JSON files from BLAST output statistics."
    )
    parser.add_argument("--boxplot-stats", type=str, required=True, help="Input boxplot statistics Parquet file.")
    parser.add_argument(
        "--min-edges",
        type=int,
        default=10,
        help="Minimum number of edges needed to retain an alignment-score group.",
    )
    parser.add_argument(
        "--min-groups",
        type=int,
        default=30,
        help="Minimum number of alignment-score groups to retain in output.",
    )
    parser.add_argument(
        "--length-json-filename",
        type=str,
        required=True,
        help="Filename for the output Alignment Length JSON.",
    )
    parser.add_argument(
        "--pident-json-filename",
        type=str,
        required=True,
        help="Filename for the output Percent Identity JSON.",
    )
    parser.add_argument(
        "--edge-hist-json-filename",
        type=str,
        required=True,
        help="Filename for the output Edge Count Histogram JSON.",
    )
    return parser

def parse_args(parser):
    """Parses command-line arguments and validates input files."""
    args = parser.parse_args()
    if not os.path.exists(args.boxplot_stats):
        print(f"Error: Input file '{args.boxplot_stats}' does not exist.")
        exit(1)
    return args

def write_json_file(data: dict, filename: str):
    """Writes dictionary data to a JSON file."""
    print(f"Writing data to {filename}")
    with open(filename, 'w') as f:
        json.dump(data, f, indent=2)


def main_plotly():
    parser = create_parser()
    args = parse_args(parser)

    print("Loading data from Parquet file...")
    df = pd.read_parquet(args.boxplot_stats)

    print("Computing groups to discard...")
    groups_to_delete = compute_outlying_groups(df[["alignment_score", "edge_count"]], args.min_edges, args.min_groups)

    print(f"Removing {len(groups_to_delete)} outlying groups...")
    df = delete_outlying_groups(df, groups_to_delete).sort_values(by="alignment_score")

    if df.empty:
        print("No data remaining after filtering. Exiting.")
        return

    # --- Create the complete Plotly configuration object ---
    x_axis_scores = df["alignment_score"].tolist()

    length_plot_config = {
        "data": [{
            "type": "box",
            "x": x_axis_scores,
            "q1": df["al_q1"].tolist(),
            "median": df["al_med"].tolist(),
            "q3": df["al_q3"].tolist(),
            "lowerfence": df["al_whislo"].tolist(),
            "upperfence": df["al_whishi"].tolist(),
        }],
        "layout": {
            "title": f"Alignment Length vs Alignment Score",
            "xaxis": {"title": "Alignment Score"},
            "yaxis": {"title": "Alignment Length"},
        }
    }
    write_json_file(length_plot_config, args.length_json_filename)

    pident_plot_config = {
        "data": [{
            "type": "box",
            "x": x_axis_scores,
            "q1": df["pident_q1"].tolist(),
            "median": df["pident_med"].tolist(),
            "q3": df["pident_q3"].tolist(),
            "lowerfence": df["pident_whislo"].tolist(),
            "upperfence": df["pident_whishi"].tolist(),
        }],
        "layout": {
            "title": f"Percent Identity vs Alignment Score",
            "xaxis": {"title": "Alignment Score"},
            "yaxis": {"title": "Percent Identity"},
        }
    }
    write_json_file(pident_plot_config, args.pident_json_filename)

    edge_hist_config = {
        "data": [{
            "type": "bar",
            "x": x_axis_scores,
            "y": df["edge_count"].tolist(),
        }],
        "layout": {
            "title": f"Number of Edges at Alignment Score",
            "xaxis": {"title": "Alignment Score"},
            "yaxis": {"title": "Number of Edges"},
        }
    }
    write_json_file(edge_hist_config, args.edge_hist_json_filename)

    print("\nPlotly configuration JSON generation complete.")

if __name__ == "__main__":
    main_plotly()

