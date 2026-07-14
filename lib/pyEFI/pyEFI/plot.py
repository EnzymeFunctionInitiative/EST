"""
Functions to construct and style plots
"""

import math

import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator, MultipleLocator, AutoLocator, AutoMinorLocator

def draw_boxplot(dd, pos, title, xlabel, ylabel, output_filename, output_filetype, dpis=None):
    """
    Render a boxplot-and-whisker plot in EFI style

    Parameters
    ----------
        dd
            contains stats for an alignment score formatted for the bxp function
        pos
            alignment scores, used as x-axis positions
        title
            plot title
        xlabel
            x-axis label
        ylabel
            y-axis label
        output_filename
            file name to save plot image to, without extension
        output_filetype
            file type to create. Should be a valid extension
        dpis
            if provided, a dict image suffixes and DPI values at which to render
            images. These are in addition to the default 96dpi image

    """
    print(f"Drawing boxplot '{title}'")
    fig, axs = plt.subplots(nrows=1, ncols=1, figsize=(20, 9))

    if dd and pos:
        axs.bxp(
            dd,
            positions=pos,
            showfliers=False,
            patch_artist=True,
            boxprops=dict(facecolor="red", edgecolor="blue", linewidth=0.5),
            whiskerprops=dict(color="gray", linewidth=0.5, linestyle="dashed"),
            medianprops=dict(color="blue", linewidth=1),
            capprops=dict(marker="o", color="gray", markersize=0.005),
        )

    label_and_render_plot(fig, axs, pos, title, xlabel, ylabel, output_filename, output_filetype, dpis)
    plt.close(fig)


def draw_histogram(xpos, heights, title, xlabel, ylabel, output_filename, output_filetype, dpis=None):
    """
    Render a histogram in EFI style

    Actually just uses plt.bars() because input data should already be binned

    Parameters
    ----------
        xpos
            x positions for bars
        heights
            parallel to xpos, heights for bars
        title
            plot title
        xlabel
            x-axis label
        ylabel
            y-axis label
        output_filename
            file name to save plot image to, without extension
        output_filetype
            file type to create. Should be a valid extension
        dpis
            if provided, a dict image suffixes and DPI values at which to render
            images. These are in addition to the default 96dpi image
    """
    print(f"Drawing histogram '{title}'")
    fig, axs = plt.subplots(nrows=1, ncols=1, figsize=(18, 9))

    if len(xpos) > 0 and len(heights) > 0:
        axs.bar(x=xpos, height=heights, edgecolor="blue", facecolor="red", linewidth=0.5, width=0.8)

    label_and_render_plot(fig, axs, xpos, title, xlabel, ylabel, output_filename, output_filetype, dpis)
    plt.close(fig)


def label_and_render_plot(fig, axs, pos, title, xlabel, ylabel, output_filename, output_filetype, dpis=None):
    """
    helper function for adding title and axis labels then rendering at various
    resolutions

    Ensures uniform style among plots

    Parameters
    ----------
        fig
            matplotlib.figure.Figure object
        axs
            matplotlib.axes.Axes object
        pos
            pandas.dataframe (shape: 1xN columns)
        title
            plot title
        xlabel
            x-axis label
        ylabel
            y-axis label
        output_filename
            file name to save plot image to. do not include an extension
        output_filetype
            image file type, must be a valid extension such as "pdf", "png", or
            "svg"
        dpis
            if provided, a dict image suffixes and DPI values at which to render
            images. These are in addition to the default 96dpi image
    """
    pos = list(pos)

    axs.set_title(title)
    axs.set_xlabel(xlabel)
    axs.set_ylabel(ylabel)
    axs.spines[["right", "top"]].set_visible(False)

    if len(pos) > 0:
        # Set the approx 30 major ticks
        axs.xaxis.set_major_locator(
            MaxNLocator(
                nbins = 29,
                steps = [1,2,2.5,5,10],
                integer = True,
                min_n_ticks = 2
            )
        )

        # Get the tick positions to set the labels
        major_ticks = axs.get_xticks()
        major_labels = [int(tick_pos) for tick_pos in major_ticks]
        axs.set_xticks(ticks = major_ticks, labels = major_labels)
        # Set the minor ticks
        axs.xaxis.set_minor_locator(AutoMinorLocator())

        # Set the y-axis ticks via the AutoLocator classes
        axs.yaxis.set_major_locator(AutoLocator())
        axs.yaxis.set_minor_locator(AutoMinorLocator())

        axs.set_xlim(pos[0] - 1, pos[-1] + 1)

        # Add grid lines for both axes' major ticks
        axs.grid(which = "major", axis = "both", color = "xkcd:light grey", linestyle = "--", alpha = 0.5) 
    else:
        # Provide default view limits for empty dataset plots
        axs.set_xlim(0, 1)
        axs.set_ylim(0, 1)
        axs.text(0.5, 0.5, "No Data Available", ha='center', va='center', fontsize=14, color='gray')

    fig.savefig(f"{output_filename}.{output_filetype}", bbox_inches="tight", dpi=300)
    axs.grid(False)

    if isinstance(dpis, dict):
        for name, dpi in dpis.items():
            fig.savefig(f"{output_filename}_{name}.{output_filetype}", bbox_inches="tight", dpi=dpi)


