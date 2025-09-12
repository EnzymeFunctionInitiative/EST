import argparse
import json
import os

def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Merge muliple json statistics files into one")
    parser.add_argument("--input", nargs="+", type=str, required=True, help="Paths to json files")
    parser.add_argument("--output", type=str, required=True, help="Desired output filename")

    return parser

def check_args(args: argparse.Namespace) -> argparse.Namespace:

    fail = False
    for filename in args.input:
        if not os.path.exists(filename):
            print(f"Input filename '{filename}' does not exist")
            fail = True
    
    if fail:
        exit(1)
    return args


if __name__ == "__main__":
    args = check_args(create_parser().parse_args())

    merged = {}

    for filename in args.input:
        with open(filename, 'r') as fh:
            data = json.load(fh)
            merged.update(data)

    with open(args.output, 'w') as output_file:
        json.dump(merged, output_file, indent=4)
