import argparse
import matplotlib.pyplot as plt
import matplotlib as mpl
import os
from pyEFI.nb_conn_colormap import get_nb_conn_colormap
import sys

def is_numeric(val):
    try:
        float(val)
        return True
    except ValueError:
        return False

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

    has_valid_input = args.input_file and os.path.isfile(args.input_file)

    # Validate arguments based on Perl script's logic
    if not has_valid_input:
        if args.min is None or args.min < 1:
            sys.exit("Error: Need --min since no file is provided")
        if not args.max:
            sys.exit("Error: Need --max since no file is provided")
        # If the file was specified but does not exist, then delete it from the namespace
        if args.input_file:
            del args.input_file

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

            # Check for the _META row to get the min max from that row, otherwise compute from data
            if k == "_META" and len(v) >= 4:
                min_val = float(v[1] if v[0] == "min" else v[3])
                max_val = float(v[3] if v[2] == "max" else v[1])
                found_min_max = True
                break

            # Check if the second column (v[0]) is numeric to find min/max dynamically
            if len(v) > 0 and is_numeric(v[0]):
                val = float(v[0])
                if val < new_min:
                    new_min = val
                if val > new_max:
                    new_max = val

    if not found_min_max:
        min_val = new_min
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
    # The Perl script used 1650x150 pixels. 
    # At 100 DPI, 16.5 x 1.5 inches provides the exact same canvas size.
    fig, ax = plt.subplots(figsize=(16.5, 1.5), dpi=100)

    if args.min is None or args.max is None or args.min == float('inf'):
        print(f"Min/max error {args.min} {args.max}: saving empty image")
        ax.axis('off')
        plt.savefig(args.output_file, bbox_inches='tight')
        return

    print(f"Found color min {args.min} and max {args.max}")

    # Set up the colormap and normalization range
    if args.matplotlib_colormap:
        # Use matplotlib standard
        cmap = plt.get_cmap(args.matplotlib_colormap) 
    else:
        # Use custom EFI
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
