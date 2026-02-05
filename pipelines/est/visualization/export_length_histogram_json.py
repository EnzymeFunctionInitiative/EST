
import argparse
import json
import os

from pyEFI.processing import count_lengths


def create_parser():
    """Creates the command-line argument parser."""
    parser = argparse.ArgumentParser(
        description="Generate a Plotly-compatible JSON file for a length histogram."
    )
    parser.add_argument(
        "--lengths",
        type=str,
        required=True,
        help="Tab-separated file containing lengths and counts.",
    )
    parser.add_argument(
        "--output-json-filename",
        type=str,
        required=True,
        help="Filename for the output Plotly JSON configuration.",
    )
    parser.add_argument(
        "--frac",
        type=float,
        default=1.0,
        help="Fraction of total length counts to include in the plot (0.0 to 1.0).",
    )
    parser.add_argument(
        "--title-extra",
        type=str,
        default="",
        help="Extra text to include in the plot title."
    )
    parser.add_argument(
        "--job-id",
        type=int,
        default=0,
        help="Scheduler job ID"
    )
    return parser

def parse_args(parser):
    """Parses command-line arguments and validates input files."""
    args = parser.parse_args()
    if not os.path.exists(args.lengths):
        print(f"Error: Input file '{args.lengths}' does not exist.")
        exit(1)
    if not (0.0 <= args.frac <= 1.0):
        print(f"Error: --frac must be between 0.0 and 1.0.")
        exit(1)
    return args

def write_json_file(data: dict, filename: str):
    """Writes dictionary data to a JSON file."""
    print(f"Writing Plotly configuration to {filename}")
    with open(filename, 'w') as f:
        json.dump(data, f, indent=2)


def main():
    """Main execution function."""
    parser = create_parser()
    args = parse_args(parser)

    print(f"Reading lengths from '{args.lengths}'...")
    df = count_lengths(args.lengths, args.frac)

    if df.empty:
        print("No data remaining after processing. No JSON file will be created.")
        return

    # --- Create the complete Plotly configuration object ---
    title = f"Number of Sequences at Each Length"
    if args.job_id:
        title += f" for Job ID {args.job_id}"
    if args.title_extra:
        title += f" {args.title_extra}"
        
    plotly_config = {
        "data": [{
            "type": "bar",
            "x": df["length"].tolist(),
            "y": df["count"].tolist(),
        }],
        "layout": {
            "title": title,
            "xaxis": {"title": "Sequence Length"},
            "yaxis": {"title": "Number of Sequences"},
        }
    }

    write_json_file(plotly_config, args.output_json_filename)
    print("\nJSON generation complete.")

if __name__ == "__main__":
    main()

