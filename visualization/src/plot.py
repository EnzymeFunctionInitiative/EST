"""
Functions to construct and style plots
"""

import math

import matplotlib.pyplot as plt


def draw_boxplot(dd, pos, title, xlabel, ylabel, output_filename, output_filetype, dpis=None):
    """
    Render a boxplot-and-whisker plot in EFI style

    Parameters:
    ---
        dd (list[dict]) - contains stats for an alignment score formatted for the bxp function
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


def draw_histogram(xpos, heights, title, xlabel, ylabel, output_filename, output_filetype, dpis=None):
    """
    Render a histogram in EFI style

    Actually just uses bars() because we've already binned

    Parameters:
    ---
        xpos (list[int]) - x positions for bars
        heights (list) - parallel to xpos, heights for bars
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
    axs.bar(x=xpos, height=heights, edgecolor="blue", facecolor="red", linewidth=0.5, width=0.8)

    label_and_render_plot(fig, axs, xpos, title, xlabel, ylabel, output_filename, output_filetype, dpis)


def label_and_render_plot(fig, axs, pos, title, xlabel, ylabel, output_filename, output_filetype, dpis=None):
    """
    helper function for adding title and axis labels then rendering at various resolutions

    Ensures uniform style among plots

    Parameters:
    ---
        title (str) - plot title
        xlabel (str) - x-axis label
        ylabel (str) - y-axis label
        output_filename - file name to save plot image to. do not include an extension
        output_filetype - image file type, must be a valid exetention such as "pdf", "png", or "svg"
        dpis (dict[str, int])- if provided, a dict image suffixes and DPI values at which to render images. These
                               are in addition to the default 96dpi image
    """
    axs.set_title(title)
    axs.set_xlabel(xlabel)
    axs.set_ylabel(ylabel)
    axs.spines[["right", "top"]].set_visible(False)

    # let's aim for about 30 xticks at 96dpi and interoplate using that
    # this number is in line with default min groups
    pos = list(pos)
    spacing = max(math.ceil((pos[-1] - pos[0]) / 30), 1)
    new_ticks = range(pos[0], pos[-1], spacing)
    axs.set_xticks(ticks=new_ticks, labels=new_ticks)
    axs.set_xlim(max(0, pos[0] - spacing), pos[-1] + 1)
    fig.savefig(f"{output_filename}.{output_filetype}", bbox_inches="tight", dpi=96)

    if isinstance(dpis, dict):
        for name, dpi in dpis.items():
            # scale x ticks based on resolution, since this part is intended
            # for rendering previews, cap number of labels at 30
            # (this means all resolutions passed in should be < 96)
            spacing = max(math.ceil((pos[-1] - pos[0]) / 30), 1)
            new_ticks = range(pos[0], pos[-1], spacing)
            axs.set_xticks(ticks=new_ticks, labels=new_ticks)
            fig.savefig(f"{output_filename}_{name}.{output_filetype}", bbox_inches="tight", dpi=dpi)
