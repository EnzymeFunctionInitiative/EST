"""
Plot data from lenght_uniprot.tab
"""
import argparse

import matplotlib.pyplot as plt
import pandas as pd

import util


def parse_args():
    parser = argparse.ArgumentParser(description="Render plots from BLAST output")
    parser.add_argument("--lengths", type=str, required=True, help="Tab-separated file containing lengths and counts")
    parser.add_argument("--job-id", required=True, help="Job ID number for BLAST output file")
    parser.add_argument("--frac", type=float, default=1, help="Percent of length values to include in plot")
    parser.add_argument("--plot-filename", type=str, required=True, help="Filename, without extention, to write the plots to")
    parser.add_argument("--title-extra", type=str, default="", help="Extra text to include plot title")
    parser.add_argument("--output-type", type=str, default="png", choices=["png", "svg", "pdf"])
    parser.add_argument("--proxies", metavar="KEY:VALUE", nargs="+", help="A list of name:dpi pairs for rendering smaller proxy images. Names wil be included in filenames, DPIs should be less than 96")
    
    args = parser.parse_args()
    args.proxies = util.parse_proxies(args.proxies)
    return args


def count_lengths(count_file: str, frac: float) -> pd.DataFrame:
    """
    Load and trim length histogram data

    This function can also trim ends of the data. The method to do this
    is borrowed from the original perl code and it seems to include a
    certain percentage of the total count.

    Parameters:
    ---
        count_file (str) - path to a 2 column tsv (length and count)
        frac (float) - percentage of counts to include
    
    Returns:
    ---
        A pandas DataFrame object with "count" and "length" columns
    """
    df = pd.read_csv(count_file, sep="\t", names=["length", "count"])
    df['sequence_sum'] = df["count"].cumsum()
    # trim values using --frac value
    end_trim = int(df["count"].sum() * (1.0-frac) / 2.0)
    df = df[(df["sequence_sum"] >= end_trim) & (df["sequence_sum"] - df["count"] <= df["count"].sum() - end_trim)]
    df = df.drop(["sequence_sum"], axis=1)

    return df


def main(lengths_file, job_id, frac, output_filename, title_extra, output_filetype, proxies):
    print(f"Reading lengths from '{lengths_file}'")
    df = count_lengths(lengths_file, frac)

    print("Plotting histogram")
    fig, axs = plt.subplots(nrows=1, ncols=1, figsize=(18, 9))
    axs.bar(x=df["length"], height=df["count"], edgecolor="blue", facecolor="red", linewidth=0.5, width=.8)
    util.label_and_render_plot(fig, axs, df["length"], f"Number of Sequences at Each Length for Job ID {job_id} {title_extra}",
                        "Sequence Length", "Number of Sequences", output_filename, output_filetype, dpis=proxies)

if __name__ == "__main__":
    args = parse_args()
    main(args.lengths, args.job_id, args.frac, args.plot_filename, args.title_extra, args.output_type, args.proxies)
