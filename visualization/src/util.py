"""
Utilities and helper functions
"""


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
    axs.spines[['right', 'top']].set_visible(False)

    # let's aim for about 30 xticks at 96dpi and interoplate using that
    # this number is in line with default min groups
    pos = list(pos)
    spacing = int(max(len(pos) / 30, 1))
    new_ticks = range(pos[0],pos[-1], spacing)
    axs.set_xticks(ticks=new_ticks, labels=new_ticks)
    axs.set_xlim(0, pos[-1]+1)
    fig.savefig(f"{output_filename}.{output_filetype}", dpi=96)

    if type(dpis) == dict:
        for name, dpi in dpis.items():
            # scale x ticks based on resolution, since this part is intended
            # for rendering previews, cap number of labels at 30
            # (this means all resolutions passed in should be < 96)
            scaling_factor = min(30.0/96.0 * dpi, 30)
            spacing = int(max(len(pos) / scaling_factor, 1))
            new_ticks = range(pos[0],pos[-1], spacing)
            axs.set_xticks(ticks=new_ticks, labels=new_ticks)
            fig.savefig(f"{output_filename}_{name}.{output_filetype}", dpi=dpi)