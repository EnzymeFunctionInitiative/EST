import argparse
import json
import os
from typing import Any, Dict

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

def deep_merge(base: Dict[Any, Any], update: Dict[Any, Any]) -> Dict[Any, Any]:
    """
    Recursively merges 'update' into 'base'.
    """
    for key, value in update.items():
        if key in base and isinstance(base[key], dict) and isinstance(value, dict):
            # Both are dicts, dive deeper
            deep_merge(base[key], value)
        else:
            # Not a dict or key doesn't exist, just assign/overwrite
            base[key] = value
    return base

if __name__ == "__main__":
    args = check_args(create_parser().parse_args())

    merged_data = {}

    for filename in args.input:
        try:
            with open(filename, 'r') as fh:
                data = json.load(fh)
                # Use deep_merge instead of .update()
                deep_merge(merged_data, data)
        except json.JSONDecodeError:
            print(f"Error: '{filename}' is not a valid JSON file. Skipping.")

    with open(args.output, 'w') as output_file:
        json.dump(merged_data, output_file, indent=4)
