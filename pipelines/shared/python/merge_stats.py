import argparse
import json
import os

def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Merge statistic files into a file stats.json file")
    parser.add_argument("--import-stats", type=str, required=True, help="Path to file containing import sequence statistics")
    parser.add_argument("--conv-ratio-stats", type=str, required=True, help="Path to file containing convergence ratio statistics")
    parser.add_argument("--output", type=str, required=True, help="Desired output filename")

    return parser

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    fail = False
    if not os.path.exists(args.import_stats):
        print(f"Input import stats '{args.import_stats}' does not exist")
        fail = True
    if not os.path.exists(args.conv_ratio_stats):
        print(f"Input conv ratio stats '{args.conv_ratio_stats}' does not exist")
        fail = True
    
    if fail:
        exit(1)
    else:
        args.import_stats = os.path.abspath(args.import_stats)
        args.conv_ratio_stats = os.path.abspath(args.conv_ratio_stats)
        return args


if __name__ == "__main__":
    args = check_args(create_parser().parse_args())

    import_data = {}
    with open(args.import_stats, 'r') as ifh:
        import_data = json.load(ifh)

    conv_ratio_data = {}
    with open(args.conv_ratio_stats, 'r') as cfh:
        conv_ratio_data = json.load(cfh)

    import_data.update(conv_ratio_data)

    with open(args.output, 'w') as output_file:
        json.dump(import_data, output_file, indent=4)
