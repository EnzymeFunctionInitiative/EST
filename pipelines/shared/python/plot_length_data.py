
import argparse
import os

import matplotlib.pyplot as plt

from pyEFI.cli import parse_proxies
from pyEFI.plot import label_and_render_plot
from pyEFI.processing import count_lengths


def create_parser():
    parser = argparse.ArgumentParser(description="Render plots from BLAST output")
    parser.add_argument(
        "--lengths",
        type=str,
        required=True,
        help="Tab-separated file containing lengths and counts",
    )
    parser.add_argument("--job-id", required=False, help="Job ID number for BLAST output file")
    parser.add_argument("--frac", type=float, default=1, help="Percent of length values to include in plot")
    parser.add_argument(
        "--plot-filename",
        type=str,
        required=True,
        help="Filename, without extension, to write the plots to",
    )
    parser.add_argument("--title", required=False, type=str, default="", help="Set the plot title (if provided, --title-extra and --job-id are ignored)")
    parser.add_argument("--title-extra", type=str, default="", help="Extra text to include plot title")
    parser.add_argument("--output-type", type=str, default="png", choices=["png", "svg", "pdf"])
    parser.add_argument(
        "--proxies",
        metavar="KEY:VALUE",
        nargs="+",
        help="A list of name:dpi pairs for rendering smaller proxy images. Names will be included in filenames, DPIs should be less than 96",
    )

    return parser

def parse_args(parser):
    args = parser.parse_args()
    args.proxies = parse_proxies(args.proxies)

    # Validate input filepaths
    fail = False
    if not os.path.exists(args.lengths):
        print(f"Lengths file {args.lengths} does not exist")
        fail = True
    if fail:
        exit(1)
    else:
        return args


def main(lengths_file, frac, output_filename, plot_title, output_filetype, proxies):
    print(f"Reading lengths from '{lengths_file}'")
    df = count_lengths(lengths_file, frac)

    if (len(df) == 0):
        print("No data remaining after processing. No image files will be created.")
        return

    print("Plotting histogram")
    fig, axs = plt.subplots(nrows=1, ncols=1, figsize=(18, 9))
    axs.bar(
        x=df["length"],
        height=df["count"],
        edgecolor="blue",
        facecolor="red",
        linewidth=0.5,
        width=0.8,
    )
    label_and_render_plot(
        fig,
        axs,
        df["length"],
        plot_title,
        "Sequence Length",
        "Number of Sequences",
        output_filename,
        output_filetype,
        dpis=proxies,
    )
    plt.close(fig)

def get_plot_title(job_id, title, title_extra):
    if title:
        return title
    else:
        job_id_arg = f" for Job ID {job_id}" if job_id else ""
        extra_arg = f" {title_extra}" if title_extra else ""
        plot_title = f"Number of Sequences at Each Length{job_id_arg}{extra_arg}"
        return plot_title

if __name__ == "__main__":
    args = parse_args(create_parser())
    plot_title = get_plot_title(args.job_id, args.title, args.title_extra)
    main(
        args.lengths,
        args.frac,
        args.plot_filename,
        plot_title,
        args.output_type,
        args.proxies,
    )
