import argparse
import shutil
import os

import numpy as np
import pandas as pd

from plot import draw_boxplot, draw_histogram
from util import parse_proxies


def parse_args():
    parser = argparse.ArgumentParser(description="Render plots from BLAST output")
    parser.add_argument("--boxplot-stats", type=str, required=True, help="Boxplot statisitcs parquet file")
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
        help="A list of key:value pairs for rendering smaller proxy images. Keys wil be included in filenames, values should be less than 96",
    )

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


def compute_outlying_groups(group_edge_counts: pd.DataFrame, min_num_edges: int, min_num_groups: int) -> set[int]:
    """
    Determine groups to exclude from plots

    Considers groups in sorted order and locates the first and last group which has less than
    ``min_num_edges``. Cuts groups that are less than the first or greater than the last group. Some
    groups between these endpoints may still have less than `min_num_edges`. If the the number of
    groups present after removing the outliers is less than `min_group_size`, the upper cutoff
    index is incremented until the group size meets the minimum or no more groups are left to
    include.

    Parameters
    ----------
        group_metadata
            cache metadata from `group_output_data`

        min_num_edges
            minimum number of edges needed to retain a group

        min_num_groups
            keep at least this many groups (may override min_num_edges)

    Returns
    -------
        A set of group numbers to exclude
    """
    sizes = sorted(group_edge_counts.itertuples(index=False))

    lower_bound_idx = 0
    upper_bound_idx = 0
    # find first group with at least min_num_edges edges
    for i, t in enumerate(sizes):
        if t.edge_count >= min_num_edges:
            lower_bound_idx = i
            break

    # find last group with at least min_num_edges edges
    for i, t in enumerate(reversed(sizes)):
        if t.edge_count >= min_num_edges:
            upper_bound_idx = i
            break

    # ensure we have at least min_num_groups, walk upper index forward if not
    while upper_bound_idx < len(sizes) and upper_bound_idx - lower_bound_idx + 1 < min_num_groups:
        upper_bound_idx += 1
    # extract `alignment_score`s from sizes array, put in Set of O(1) lookups in subsequent filter
    groups_to_keep = set(k.alignment_score for k in sizes[lower_bound_idx:-upper_bound_idx])

    return set([k.alignment_score for k in sizes]) - groups_to_keep


def delete_outlying_groups(stats: pd.DataFrame, groups_to_delete: set) -> pd.DataFrame:
    """
    Removes outlying groups from metadata

    Parameters
    ----------
        stats
            dataframe of boxplot stats

        groups_to_delete
            set of alignment scores to exclude from the returned dataframe

    Returns
    -------
        Metadata dict with groups removed
    """
    return stats[~stats["alignment_score"].isin(groups_to_delete)]

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

    print("Computing groups to discard")
    groups_to_delete = compute_outlying_groups(df[["alignment_score", "edge_count"]], min_edges, min_groups)

    print(f"Removing {len(groups_to_delete)} groups")
    df = delete_outlying_groups(df, groups_to_delete)

    # plot alignment_length
    print("Plotting alignment length")
    length_dd = df[["al_whislo", "al_q1", "al_med", "al_q3", "al_whishi"]].rename(columns=lambda x: x.split("_")[1]).to_dict(orient="records")
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
    args = parse_args()
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
