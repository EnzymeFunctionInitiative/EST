
import argparse
import os

import pandas as pd

from pyEFI.cli import parse_proxies
from pyEFI.plot import draw_boxplot, draw_histogram
from pyEFI.processing import compute_outlying_groups, delete_outlying_groups


def create_parser():
    parser = argparse.ArgumentParser(description="Render plots from BLAST output")
    parser.add_argument("--boxplot-stats", type=str, required=True, help="Boxplot statistics parquet file")
    parser.add_argument("--job-id", required=True, help="Job ID number for BLAST output file")
    parser.add_argument(
        "--min-edges",
        type=int,
        default=10,
        help="Minimum number of edges needed to retain an alignment-score group",
    )
    parser.add_argument(
        "--min-groups",
        type=int,
        default=30,
        help="Minimum number of alignment-score groups to retain in output",
    )
    parser.add_argument(
        "--length-plot-filename",
        type=str,
        required=True,
        help="Filename, without extension, to write the alignment length boxplots to",
    )
    parser.add_argument(
        "--pident-plot-filename",
        type=str,
        required=True,
        help="Filename, without extension, to write the percent identity boxplots to",
    )
    parser.add_argument(
        "--edge-hist-filename",
        type=str,
        required=True,
        help="Filename, without extension, to write the edge count histograms to",
    )
    parser.add_argument("--output-type", type=str, default="png", choices=["png", "svg", "pdf"])
    parser.add_argument(
        "--proxies",
        metavar="KEY:VALUE",
        nargs="+",
        help="A list of key:value pairs for rendering smaller proxy images. Keys will be included in filenames, values should be less than 96",
    )

    return parser

def parse_args(parser):
    args = parser.parse_args()
    args.proxies = parse_proxies(args.proxies)

    # validate input filepaths
    fail = False
    if not os.path.exists(args.boxplot_stats):
        print(f"BLAST output '{args.boxplot_stats}' does not exist")
        fail = True
    if fail:
        exit(1)
    else:
        return args


def main(
    boxplot_stats,
    job_id,
    min_edges,
    min_groups,
    length_filename,
    pident_filename,
    edge_filename,
    output_format,
    proxies,
):
    # compute groups and trim outliers
    print("Loading output data")
    df = pd.read_parquet(boxplot_stats)
    df["_label"] = ""

    print("Computing groups to discard")
    groups_to_delete = compute_outlying_groups(df[["alignment_score", "edge_count"]], min_edges, min_groups)

    print(f"Removing {len(groups_to_delete)} groups")
    df = delete_outlying_groups(df, groups_to_delete)

    # plot alignment_length
    print("Plotting alignment length")
    length_dd = df[["al_whislo", "al_q1", "al_med", "al_q3", "al_whishi","_label"]].rename(columns=lambda x: x.split("_")[1]).to_dict(orient="records")
    length_xpos = sorted(df["alignment_score"])
    draw_boxplot(
        length_dd,
        length_xpos,
        f"Alignment Length vs Alignment Score for Job {job_id}",
        "Alignment Score",
        "Alignment Length",
        length_filename,
        output_format,
        dpis=proxies,
    )

    # percent identical box plot data
    print("Plotting percent identical")
    pident_dd = df[["pident_whislo", "pident_q1", "pident_med", "pident_q3", "pident_whishi"]].rename(columns=lambda x: x.split("_")[1]).to_dict(orient="records")
    pident_xpos = sorted(df["alignment_score"])
    draw_boxplot(
        pident_dd,
        pident_xpos,
        f"Percent Identical vs Alignment Score for Job {job_id}",
        "Alignment Score",
        "Percent Identical",
        pident_filename,
        output_format,
        dpis=proxies,
    )

    # draw edge length histogram
    print("Extracting histogram data")
    xpos, heights = df["alignment_score"], df["edge_count"]
    draw_histogram(
        xpos,
        heights,
        f"Number of Edges at Alignment Score for Job {job_id}",
        "Alignment Score",
        "Number of Edges",
        edge_filename,
        output_format,
        dpis=proxies,
    )


if __name__ == "__main__":
    args = parse_args(create_parser())
    main(
        args.boxplot_stats,
        args.job_id,
        args.min_edges,
        args.min_groups,
        args.length_plot_filename,
        args.pident_plot_filename,
        args.edge_hist_filename,
        args.output_type,
        args.proxies
    )
