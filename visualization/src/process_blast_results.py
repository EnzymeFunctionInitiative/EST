"""
Filters, summarizes, and plots BLAST output using Pandas and matplotlib and
computes cumulative-sum table for alignment scores
"""

import argparse

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from util import label_and_render_plot

def parse_args():
    parser = argparse.ArgumentParser(description="Render plots from BLAST output")
    parser.add_argument("--blast-output", type=str, required=True, help="7-column output file from BLAST")
    parser.add_argument("--job-id", required=True, help="Job ID number for BLAST output file")
    parser.add_argument("--min-edges", 
                        type=int, default=10, 
                        help="Minimum number of edges needed to retain an alignment-score group")
    parser.add_argument("--min-groups", 
                        type=int, default=30, 
                        help="Minimum number of alignment-score groups to retain in output")
    parser.add_argument("--length-plot-filename", type=str, required=True, help="Filename, without extention, to write the alignment length boxplots to")
    parser.add_argument("--pid-plot-filename", type=str, required=True, help="Filename, without extention, to write the percent identity boxplots to")
    parser.add_argument("--edge-hist-filename", type=str, required=True, help="Filename, without extention, to write the edge count histograms to")
    parser.add_argument("--output-type", type=str, default="png", choices=["png", "svg", "pdf"])
    
    args = parser.parse_args()
    return args

def filter_outlying_groups(df, min_num_edges, min_num_groups):
    """
    trim left and right ends of dataset while retaining minimum number of groups

    Data is summarized primarily by grouping by a discretized alignment score. It is
    possible that some alignment scores, particlarly high ones, do not contain very
    many edges. We want these trimmed off the ends of the dataset to limit the x-axis
    range. However, a minimum resolution needs to be retained in the dataset, so we
    ensure that some minimum number of groups is retained, even if some have less than
    the desired numberof edges. If the number of groups falls below the minimum, the right
    tail is extended until the minimum group size is attained.

    Parameters:
    ---
        df (pd.DataFrame) - BLAST output dataframe
        min_num_edges (int) - number of edges required to retain a group
        min_num_groups (int) - at least this many groups will be returned
    
    Returns:
    ---
        A pd.DataFrameGroupBy object which can be passed to `compute_summary_statistics`
    """
    print(f"Keeping groups with >= {min_num_edges} edges and at least {min_num_groups} groups")
    groups = df.groupby(by="alignment_score")
    if len(groups.groups) <= min_num_groups:
        return set()
    
    # get list of tuples of [(alignment_score, group_size), ...] sorted low to high
    print("computing sizes")
    sizes = [(k, len(groups.groups[k])) for k in sorted(groups.groups.keys())]
    lower_bound_idx = 0
    upper_bound_idx = 0
    print("finding lower index")
    # find first group with at least min_num_edges edges
    for i, t in enumerate(sizes):
        if t[1] >= min_num_edges:
            lower_bound_idx = i
            break
    
    print("finding upper index")
    # find last group with at least min_num_edges edges
    for i, t in enumerate(reversed(sizes)):
        if t[1] >= min_num_edges:
            upper_bound_idx = i
            break

    print("correcting groups")
    # ensure we have at least min_num_groups, walk upper index forward if not
    while upper_bound_idx < len(sizes) and upper_bound_idx - lower_bound_idx + 1 < min_num_groups:
        upper_bound_idx += 1
    # extract `alignment_score`s from sizes array, put in Set of O(1) lookups in subsequent filter
    print("computing groups to keep")
    groups_to_keep = set([k for k, _ in sizes[lower_bound_idx:-upper_bound_idx]])
    
    return groups_to_keep

def compute_summary_stats(groups, field):
    """
    computes summary and stores in dict so that it can be plotted with axs.bxp
    
    See https://matplotlib.org/stable/api/_as_gen/matplotlib.axes.Axes.bxp.html. The R
    code that this was based on just called `boxplot`, which uses `boxplot.stats`, which
    in turn uses `fivenum` which computes a Tukey five number summary
    (https://en.wikipedia.org/wiki/Five-number_summary) of the data, *not* quartiles. 

    Parameters:
        groups (pd.DataFrameGroupBy) - BLAST data grouped by alignment score, optionally filtered
        field (str) - the field, either `alignment_length` or `percent_identical` to summarize

    Returns:
    ---
        dd (list[dict]) - list of dicts, one per row. these become boxes in the plot
        pos (list[int]) - alignment score values, used to position boxes on x axis
    
    """
    print(f"Computing summary statistics for {field}")
    df_summary = pd.DataFrame()
    df_summary["med"] = groups[field].mean()
    df_summary["q1"] = groups[field].quantile(.25)
    df_summary["q3"] = groups[field].quantile(.75)
    df_summary["whislo"] = groups[field].min()
    df_summary["whishi"] = groups[field].max()
    dd = df_summary.to_dict(orient='records')
    pos = df_summary.index
    return dd, pos

def draw_boxplot(dd, pos, title, xlabel, ylabel, output_filename, output_filetype, dpis=None):
    """
    Render a boxplot-and-whisker plot in EFI style

    Parameters:
    ---
        dd (list[dict]) - output from `compute_summary_statistics`, contains stats for an alignment score
        pos (list) - alignment scores, used as x-axis positions
        title (str) - plot title
        xlabel (str) - x-axis label
        ylabel (str) - y-axis label
        output_filename - file name to save plot image to, without extention
        output_filetype - file type to create. Should be a valid extention
        dpis (dict[str, int])- if provided, a dict image suffixes and DPI values at which to render images. These
                               are in addition to the default 96dpi image

    """
    print(f"Drawing boxplot '{title}'")
    fig, axs = plt.subplots(nrows=1, ncols=1, figsize=(20, 9))
    axs.bxp(dd, positions=pos, showfliers=False, patch_artist=True,
        boxprops=dict(facecolor="red", edgecolor="blue", linewidth=0.5),
        whiskerprops=dict(color="gray", linewidth=0.5, linestyle="dashed"),
        medianprops=dict(color="blue", linewidth=1),
        capprops=dict(marker="o", color="gray", markersize=.005))

    label_and_render_plot(fig, axs, pos, title, xlabel, ylabel, output_filename, output_filetype, dpis)

def draw_histogram(df, pos, x_field, height_field, title, xlabel, ylabel, output_filename, output_filetype, dpis=None):
    """
    Render a histogram in EFI style

    Actually just uses bars() because we've already binned

    Parameters:
    ---
        df_edges (pd.Dataframe) - dataframe with "alignment_score" and "alignment_length" columns
        title (str) - plot title
        xlabel (str) - x-axis label
        ylabel (str) - y-axis label
        output_filename - file name to save plot image to, without extention
        output_filetype - file type to create. Should be a valid extention
        dpis (dict[str, int])- if provided, a dict image suffixes and DPI values at which to render images. These
                               are in addition to the default 96dpi image
    """
    print(f"Drawing histogram '{title}'")
    fig, axs = plt.subplots(nrows=1, ncols=1, figsize=(18, 9))
    axs.bar(x=df[x_field], height=df[height_field], edgecolor="blue", facecolor="red", linewidth=0.5, width=.8)

    label_and_render_plot(fig, axs, pos, title, xlabel, ylabel, output_filename, output_filetype, dpis)

def main(blast_output, job_id, min_edges, min_groups, length_filename, pid_filename, edge_filename, output_format):
    #
    # Load data
    #
    print(f"Loading data from '{args.blast_output}'")
    df = pd.read_csv(blast_output, sep="\t", header=None, usecols=[2,3,4,5,6])

    # not sure what all of the columns in the file are but these names are used later
    df = df.rename({2:"percent_identical", 3:"alignment_length"}, axis=1)

    # Compute alignment score (e-value), this is done in the preproccesing step if enabled
    print("Computing alignment scores")
    df["alignment_score"] = (-(np.log(df[5] * df[6]) / np.log(10)) + df[4] * np.log(2) / np.log(10)).astype(int)
    # then drop the unnamed columns, they are not used again
    df = df.drop([4,5,6], axis=1)

    # calculate alignment score output table
    print("Generating alignment score cumulative sum output table")
    df_alignment_score_table = df.groupby(by="alignment_score")["alignment_length"].count().reset_index()
    df_alignment_score_table["cumulative_sum"] = df_alignment_score_table.loc[::-1,"alignment_length"].cumsum()[::-1]
    df_alignment_score_table.to_csv(f"alignment_score_{job_id}.tsv", sep="\t", index=False, header=False)
    # free this df to save memory
    del df_alignment_score_table

    #
    # Filter outlying scores
    #
    # filter out groups at beginning and end to prevent long x-axes
    print("Filtering sequences")
    groups_to_keep = filter_outlying_groups(df, min_edges, min_groups)
    groups = df.groupby("alignment_score").filter(lambda x: x.name in groups_to_keep).groupby(by="alignment_score")
    
    #
    # Compute data for plot rendering and render plots
    #
    dpis={"small": 48}
    # alignment length box plot data
    dd, pos = compute_summary_stats(groups, "alignment_length")
    draw_boxplot(dd, pos, f"Alignment Length vs Alignment Score for Job {job_id}",
                "Alignment Score", "Alignment Length", length_filename, output_format, dpis=dpis)
    
    # percent identical box plot data
    dd, pos = compute_summary_stats(groups, "percent_identical")
    draw_boxplot(dd, pos, f"Percent Identical vs Alignment Score for Job {job_id}",
                "Alignment Score", "Percent Identical", pid_filename, output_format, dpis=dpis)
    
    # counts per alignment score histogram data - reset_index() moves scores from the index to a column
    # then `alignment_length` contains counts
    df_edges = groups["alignment_length"].count().reset_index()
    draw_histogram(df_edges, df_edges.index, "alignment_score", "alignment_length", f"Number of Edges at Alignment Score for Job {args.job_id}", 
                "Alignment Score", "Number of Edges", edge_filename, output_format, dpis=dpis)

if __name__ == "__main__":
    args = parse_args()
    main(args.blast_output, args.job_id, args.min_edges, args.min_groups,
         args.length_plot_filename, args.pid_plot_filename, args.edge_hist_filename, args.output_type)