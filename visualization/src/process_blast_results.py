"""
Filters, summarizes, and plots BLAST output using Pandas and matplotlib and
computes cumulative-sum table for alignment scores
"""

import argparse
from math import log10
import os
import shutil
from uuid import uuid4

import numpy as np

from plot import draw_boxplot, draw_histogram
from cachemanager import CacheManager

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

def group_output_data(blast_output):
    log10of2 = log10(2)
    with open(blast_output) as f:
        cachedir = f"./data_{str(uuid4()).split('-')[0]}"
        with CacheManager(cachedir) as cm:
            for i, line in enumerate(f):
                fields = line.strip().split("\t")
                percent_identical = fields[2]
                alignment_length = fields[3]
                fields[3:] = list(map(float, fields[3:]))
                alignment_score = int(-(log10(fields[5] * fields[6])) + fields[4] * log10of2)

                cm.append(alignment_score, alignment_length, percent_identical)

            cm.save_edge_counts("evalue.tab")
            metadata = cm.get_edge_counts_and_filenames()
    
    return metadata, cachedir

def compute_outlying_groups(group_metadata, min_num_edges, min_num_groups):
    sizes = [(k, group_metadata[k].edge_count) for k in sorted(group_metadata.keys())]
    
    lower_bound_idx = 0
    upper_bound_idx = 0
    # find first group with at least min_num_edges edges
    for i, t in enumerate(sorted(sizes)):
        if t[1] >= min_num_edges:
            lower_bound_idx = i
            break

    # find last group with at least min_num_edges edges
    for i, t in enumerate(reversed(sizes)):
        if t[1] >= min_num_edges:
            upper_bound_idx = i
            break

    # ensure we have at least min_num_groups, walk upper index forward if not
    while upper_bound_idx < len(sizes) and upper_bound_idx - lower_bound_idx + 1 < min_num_groups:
        upper_bound_idx += 1
    # extract `alignment_score`s from sizes array, put in Set of O(1) lookups in subsequent filter
    groups_to_keep = set(k for k, _ in sizes[lower_bound_idx:-upper_bound_idx])

    return set([k for k, _ in sizes]) - groups_to_keep

def compute_summary_statistic_for_group(filename):
    group_data = np.loadtxt(filename, dtype=np.float32)
    fivenum = np.quantile(group_data, [0, .25, .5, .75, 1])
    bxp_summary =  {"whislo": fivenum[0], "q1": fivenum[1], "med": fivenum[2], "q3": fivenum[3], "whishi": fivenum[4]}
    return bxp_summary

def compute_summary_statistics(metadata, field):
    summary = []
    xpos = sorted(list(metadata.keys()))
    for group in xpos:
        fname = metadata[group]._asdict()[field]
        summary.append(compute_summary_statistic_for_group(fname))
    return summary, xpos

def delete_outlying_groups(metadata, groups_to_delete):
    for group in groups_to_delete:
        os.remove(metadata[group].length_filename)
        os.remove(metadata[group].perid_filename)
        del metadata[group]
    return metadata

def get_edge_hist_data(metadata):
    xpos = sorted(list(metadata.keys()))
    heights = [metadata[k].edge_count for k in xpos]
    return xpos, heights

def main(blast_output, job_id, min_edges, min_groups, length_filename, pid_filename, edge_filename, output_format, delete_cache=True):
    # compute groups and trim outliers
    print("grouping output data")
    metadata, cachedir = group_output_data(blast_output)

    print("computing groups to discard")
    groups_to_delete = compute_outlying_groups(metadata, min_edges, min_groups)

    print(f"deleting {len(groups_to_delete)} groups")
    metadata = delete_outlying_groups(metadata, groups_to_delete)

    # plot alignment_length
    print("Computing boxplot stats for alignment length")
    length_dd, length_xpos = compute_summary_statistics(metadata, "length_filename")
    draw_boxplot(length_dd, length_xpos, f"Alignment Length vs Alignment Score for Job {job_id}",
                "Alignment Score", "Alignment Length", length_filename, output_format)

    # percent identical box plot data
    print("Computing boxplot stats for percent identical")
    perid_dd, perid_xpos = compute_summary_statistics(metadata, "perid_filename")
    draw_boxplot(perid_dd, perid_xpos, f"Percent Identical vs Alignment Score for Job {job_id}",
                "Alignment Score", "Percent Identical", pid_filename, output_format)
    
    # draw edge length histogram
    print("Extracting histogram data")
    xpos, heights = get_edge_hist_data(metadata)
    draw_histogram(xpos, heights, f"Number of Edges at Alignment Score for Job {job_id}",
                "Alignment Score", "Number of Edges", edge_filename, output_format)

    # cleanup cache dir
    if delete_cache:
        shutil.rmtree(cachedir)

if __name__ == "__main__":
    args = parse_args()
    main(args.blast_output, args.job_id, args.min_edges, args.min_groups,
         args.length_plot_filename, args.pid_plot_filename, args.edge_hist_filename, args.output_type)