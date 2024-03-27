from util import label_and_render_plot

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
    axs.bxp(dd, positions=pos, showfliers=False, patch_artist=True,
        boxprops=dict(facecolor="red", edgecolor="blue", linewidth=0.5),
        whiskerprops=dict(color="gray", linewidth=0.5, linestyle="dashed"),
        medianprops=dict(color="blue", linewidth=1),
        capprops=dict(marker="o", color="gray", markersize=.005))

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
    axs.bar(x=xpos, height=heights, edgecolor="blue", facecolor="red", linewidth=0.5, width=.8)

    label_and_render_plot(fig, axs, xpos, title, xlabel, ylabel, output_filename, output_filetype, dpis)