"""
Plot data from lenght_uniprot.tab
"""
import argparse

from Bio import SeqIO
import matplotlib.pyplot as plt
import pandas as pd

from util import label_and_render_plot


def parse_args():
    parser = argparse.ArgumentParser(description="Render plots from BLAST output")
    parser.add_argument("--fasta", type=str, required=True, help="FASTA file containing all sequences")
    parser.add_argument("--job-id", required=True, help="Job ID number for BLAST output file")
    parser.add_argument("--frac", type=float, default=1, help="Percent of length values to include in plot")
    parser.add_argument("--plot-filename", type=str, required=True, help="Filename, without extention, to write the plots to")
    parser.add_argument("--output-type", type=str, default="png", choices=["png", "svg", "pdf"])
    
    args = parser.parse_args()
    return args


def count_lengths(fasta_file: str, frac: float) -> pd.DataFrame:
    """
    Aggregate length-counts of sequences in given FASTA

    This function can also trim ends of the data. The method to do this
    is borrowed from the original perl code and it seems to include a
    certain percentage of the total count.

    Parameters:
    ---
        fasta_file (str) - path to the FASTA file
        frac (float) - percentage of counts to include
    
    Returns:
    ---
        A pandas DataFrame object with "count" and "length" columns
    """
    lengths = {}
    with open(fasta_file) as f:
        for record in SeqIO.parse(f, "fasta"):
            l = len(str(record.seq))
            lengths[l] = lengths.get(l, 0) + 1

    # this line converts from {length1: count1, length2: count2,...}
    # to (length1, length2,...), (count1, count2,...) which become
    # columns
    lengths, counts = zip(*sorted(lengths.items()))
    df = pd.DataFrame({"length": lengths, "count": counts})
    df['sequence_sum'] = df["count"].cumsum()
    # trim values using --frac value
    end_trim = int(df["count"].sum() * (1.0-frac) / 2.0)
    df = df[(df["sequence_sum"] >= end_trim) & (df["sequence_sum"] - df["count"] <= df["count"].sum() - end_trim)]
    df = df.drop(["sequence_sum"], axis=1)

    return df


def main(fasta_file, job_id, frac, output_filename, output_filetype):
    df = count_lengths(fasta_file, frac)

    fig, axs = plt.subplots(nrows=1, ncols=1, figsize=(18, 9))
    axs.bar(x=df["length"], height=df["count"], edgecolor="blue", facecolor="red", linewidth=0.5, width=.8)
    label_and_render_plot(fig, axs, df["length"], f"Sequence Count vs Length for Job {job_id}",
                        "Sequence Length", "Number of Sequences", output_filename, output_filetype, dpis={"small": 48})

if __name__ == "__main__":
    args = parse_args()
    main(args.fasta, args.job_id, args.frac, args.plot_filename, args.output_type)
