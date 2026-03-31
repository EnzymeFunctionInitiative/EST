import argparse
import json
import os

def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Process taxonomy tool stats.")
    parser.add_argument("--stats-file", nargs="+", type=str, required=True, help="List of paths to stats files")
    parser.add_argument("--output", type=str, required=True, help="Desired output filename")

    return parser

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    fail = False
    stats_files_list = []
    for stat_file in args.stats_file:
        if not os.path.exists(stat_file):
            print(f"Stats file '{stat_file}' does not exist")
            fail = True
        else:
            stats_files_list.append(os.path.abspath(stat_file))
    
    if fail:
        exit(1)
    else:
        args.stats_file = stats_files_list
        return args


if __name__ == "__main__":
    args = check_args(create_parser().parse_args())

    combined = {}

    # loop over the stats files and update; detection of overwriting already
    # set values associated with keys is not currently implemented.
    for stats_file in args.stats_file:
        with open(stats_file, "r") as f:
            stats = json.load(f)
            print(stats)
        combined.update(stats)

    print(combined)
    # the website needs to have the number ids contained by the
    # sunburst_tax.json file set to the "num_unique_ids" key
    combined.update(
        {
            "num_unique_ids": combined.get("num_sunburst_ids",0)
        }
    )
    print(combined)

    with open(args.output, "w") as f:
        json.dump(combined, f, indent=4)
        f.write("\n")

