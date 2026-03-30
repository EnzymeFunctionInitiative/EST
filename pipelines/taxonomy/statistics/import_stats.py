import argparse
import json
import os

def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Process taxonomy tool stats.")
    parser.add_argument("--sunburst-file", type=str, required=True, help="Path to the sunburst data file")
    parser.add_argument("--stats-file", type=str, required=True, help="Path to the import stats file")
    parser.add_argument("--output", type=str, required=True, help="Desired output filename")

    return parser

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    fail = False
    if not os.path.exists(args.sunburst_file):
        print(f"Sunburst result file '{args.sunburst_file}' does not exist")
        fail = True
    if not os.path.exists(args.stats_file):
        print(f"Filtering stats file '{args.stats_file}' does not exist")
        fail = True
    
    if fail:
        exit(1)
    else:
        args.sunburst_file = os.path.abspath(args.sunburst_file)
        args.stats_file = os.path.abspath(args.stats_file)
        return args


if __name__ == "__main__":
    args = check_args(create_parser().parse_args())
    with open(args.sunburst_file, "r") as f:
        sunburst_data = json.load(f)

    # the number of sequences having been gathered for the sunburst data is
    # hardcoded in `sunburst_data["data"]["nq"]`
    num_seqs = sunburst_data["data"]["nq"]

    with open(args.stats_file, "r") as f:
        import_stats = json.load(f)

    import_stats.update(
        {
            "num_unique_ids": num_seqs
        }
    )

    with open(args.output, "w") as f:
        json.dump(import_stats, f, indent=4)
        f.write("\n")

