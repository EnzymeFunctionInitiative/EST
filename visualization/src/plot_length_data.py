"""
Plot data from lenght_uniprot.tab
"""
import argparse

import pandas as pd
import matplotlib.pyplot as plt

from util import label_and_render_plot


def parse_args():
    parser = argparse.ArgumentParser(description="Render plots from BLAST output")
    parser.add_argument("--evalue-table", type=str, required=True, help="2-column Alignment score .tsv/.tab file")
    parser.add_argument("--job-id", required=True, help="Job ID number for BLAST output file")
    
    args = parser.parse_args()
    return args


if __name__ == "__main__":
    args = parse_args()
    df = pd.read_csv(args.evalue_table, sep="\t", names=["length", "count"])

    fig, axs = plt.subplots(nrows=1, ncols=1, figsize=(18, 9))
    axs.bar(x=df["length"], height=df["count"], edgecolor="blue", facecolor="red", linewidth=0.5, width=.8)
    label_and_render_plot(fig, axs, df["length"], f"Sequence Count vs Length for {args.job_id}", 
                        "Sequence Length", "Number of Sequences", "uniprot_lengths", "png", dpis={"small": 48})