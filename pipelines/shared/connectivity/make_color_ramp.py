import argparse
import matplotlib.pyplot as plt
import matplotlib as mpl
import os
from pyEFI.nb_conn_colormap import get_nb_conn_colormap
import sys

def parse_args() -> argparse.Namespace:
    """
    Parse the command line arguments.

    Returns
    -------
        argparse Namespace containing the values needed in succeeding steps
    """
    parser = argparse.ArgumentParser(description="Generate a color ramp PNG.")
    parser.add_argument("--min", type=float, help="Minimum value for the ramp")
    parser.add_argument("--max", type=float, help="Maximum value for the ramp")
    parser.add_argument("--input-file", type=str, help="Input TSV file to infer min/max")
    parser.add_argument("--output-file", type=str, required=True, help="Output PNG file path")
    parser.add_argument("--matplotlib-colormap", type=str, help="The type of colorbar to use (acceptable values are ones supported by matplotlib color maps, e.g.  'viridis', 'jet', 'coolwarm', etc.). If not specified, a custom internal one is used")

    args = parser.parse_args()

    # Remove from args if the file path is not valid
    if args.input_file and not os.path.isfile(args.input_file):
        args.input_file = None

    return args

def update_min_max_from_file(args: argparse.Namespace):
    """
    Parse the input file to find the min and max.  The input namespace .min and .max values are
    updated with the min/max from the file.

    Parameters
    ----------
        args
            An argparse Namespace that contains the file path and any min/max that is already
            specified by the user
    """
    min_val = args.min
    max_val = args.max

    # Parse the input file to find min/max if provided
    new_min = float('inf')
    new_max = float('-inf')
    found_min_max = False

    with open(args.input_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            parts = line.split('\t')
            k = parts[0]
            v = parts[1:]

            # Check for the _META row to get the global min and max, avoiding scanning the file;
            # otherwise compute from data
            if k == "_META" and len(v) >= 4:
                min_val = float(v[1] if v[0] == "min" else v[3])
                max_val = float(v[3] if v[2] == "max" else v[1])
                found_min_max = True
                break

            # Check if the second column (v[0]) is numeric to find min/max dynamically
            if v:
                try:
                    val = float(v[0])
                    new_min = min(new_min, val)
                    new_max = max(new_max, val)
                except ValueError:
                    pass

    if not found_min_max:
        if new_min != float("inf"):
            min_val = new_min
        if new_max != float("-inf"):
            max_val = new_max

    args.min = min_val
    args.max = max_val

def plot_color_ramp(args: argparse.Namespace):
    """
    Plot the color ramp from the provided min and max properties in the input namespace.

    Parameters
    ----------
        args
            An argparse Namespace that contains the min and max that was obtained either from the
            input file or command line arguments, and the output file path
    """
    # Setup the figure canvas
    fig, ax = plt.subplots(figsize=(16.5, 1.5), dpi=300)

    has_valid_min_max = (
        args.min is not None
        and args.max is not None
        and args.min != float("inf")
        and args.max != float("-inf")
        and args.min < args.max
    )

    if not has_valid_min_max:
        print(f"Min/max not found or invalid: min={args.min} max={args.max}; creating empty graph")

        ax.axis("off")

        ax.text(0.5, 0.5, "No connectivity found",
                ha="center", va="center", fontsize=14, color="gray")

        plt.savefig(args.output_file, bbox_inches="tight")
        plt.close(fig)

        print(f"Successfully wrote empty graph file to {args.output_file}")
        return

    print(f"Found color min {args.min} and max {args.max}")

    # Set up the colormap and normalization range
    if args.matplotlib_colormap:
        # Ensure that the input color map is one of the standard matplotlib color maps
        try:
            cmap = plt.get_cmap(args.matplotlib_colormap)
        except:
            # Use custom EFI mapping if the color map was invalid
            cmap = get_nb_conn_colormap()
    else:
        # Use custom EFI mapping
        cmap = get_nb_conn_colormap()

    norm = mpl.colors.Normalize(vmin=args.min, vmax=args.max)

    # Draw the color ramp (colorbar)
    cb = mpl.colorbar.ColorbarBase(ax, cmap=cmap, norm=norm, orientation='horizontal')

    # Configure the labels and ticks
    cb.set_label('Neighborhood Connectivity', fontsize=20, labelpad=15)
    ax.tick_params(labelsize=14)

    # Adjust canvas layout to accommodate labels
    plt.subplots_adjust(bottom=0.45, top=0.85, left=0.03, right=0.97)

    # Save the output
    plt.savefig(args.output_file, bbox_inches='tight')
    print(f"Successfully wrote {args.output_file}")

if __name__ == "__main__":
    args = parse_args()
    if args.input_file:
        update_min_max_from_file(args)
    plot_color_ramp(args)
