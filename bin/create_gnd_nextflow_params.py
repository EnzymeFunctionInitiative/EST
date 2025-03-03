#!/usr/bin/env python3

import argparse
import glob
import json
import os

import shared_args

NXF_SCRIPT = "pipelines/gnd/gnd.nf"

def add_args(parser: argparse.ArgumentParser):
    """
    Add arguments for GND pipeline to ``parser``
    """
    parser.add_argument("--cluster-id-map", required=True, type=str, help="The mapping of cluster numbers to IDs in the cluster for the GNDs")
    parser.add_argument("--nb-size", type=int, required=False, default=20, help="Optional number of neighbors on the left and right of the input IDs to include in the analysis, an integer > 0.")
    shared_args.add_args(parser)

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    """
    Test file paths and rewrite them to be absolute
    """
    fail = False

    # check for shared args validity
    validated_args = shared_args.check_args(args)
    if validated_args is None:
        fail = True
    else:
        args = validated_args

    if not os.path.exists(args.cluster_id_map):
        print(f"SSN Input file '{args.cluster_id_map}' does not exist")
        fail = True
    
    if args.nb_size < 0 or args.nb_size > 20:
        print(f"Neighborhood size (--nb-size) was given a bad value ({args.nb_size}).")
        fail = True

    if fail:
        print("Failed to render params template")
        exit(1)
    else:
        args.cluster_id_map = os.path.abspath(args.cluster_id_map)
        return args
    
def create_parser():
    parser = argparse.ArgumentParser(description="Render params.yml for GND nextflow pipeline")
    add_args(parser)
    return parser

def render_params(cluster_id_map, efi_config, efi_db, output_dir, job_id, nextflow_config=None):
    params = {
        "final_output_dir": output_dir,
        "cluster_id_map": cluster_id_map,
        "efi_config": efi_config,
        "efi_db": efi_db
    }
    params_file = os.path.join(output_dir, shared_args.PARAMS_NAME)
    with open(params_file, "w") as f:
        json.dump(params, f, indent=4)
    print(f"Wrote params to '{params_file}'")
    return params_file

if __name__ == "__main__":
    args = check_args(create_parser().parse_args())
    render_params(**vars(args))
    shared_args.save_run_script(args, NXF_SCRIPT)

