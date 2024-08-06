#!/usr/bin/env python3

import argparse
import json
import os

def add_args(parser: argparse.ArgumentParser):
    """
    add argumdents for Color SSN pipeline to ``parser``
    """
    parser.add_argument("--output-dir", required=True, type=str, help="Location for results. Will be created if it does not exist")
    parser.add_argument("--ssn-input", required=True, type=str, help="The SSN file to color, XGMML or zipped XGMML")
    parser.add_argument("--efi-config", required=True, type=str, help="Location of the EFI config file")
    parser.add_argument("--efi-db", required=True, type=str, help="Name of the MySQL database to use (e.g. efi_202406) or name of the SQLite file")
    parser.add_argument("--job-id", default=131, help="ID used when running on the EFI website. Not important otherwise")


def check_args(args: argparse.Namespace) -> argparse.Namespace:
    """
    Test file paths and rewrite them to be absolute
    """
    fail = False

    if not os.path.exists(args.ssn_input):
        print(f"SSN Input file '{args.ssn_input}' does not exist")
        fail = True
    
    if not os.path.exists(args.efi_config):
        print(f"EFI config file '{args.efi_config}' does not exist")
        fail = True
    
    if os.path.exists(args.output_dir):
        if len(os.listdir(args.output_dir)) > 0:
            print(f"Output directory '{args.output_dir}' is not empty, refusing to create params.yml")
            fail = True
    else:
        try:
            os.makedirs(args.output_dir)
        except Exception as e:
            print(f"Could not create output directory '{args.output_dir}': {e}")
            fail = True


    if fail:
        print("Failed to render params template")
        exit(1)
    else:
        args.output_dir = os.path.abspath(args.output_dir)
        args.ssn_input = os.path.abspath(args.ssn_input)
        args.efi_config = os.path.abspath(args.efi_config)
        if os.path.exists(args.efi_db):
            args.efi_db = os.path.abspath(args.efi_db)
        return args
    
def create_parser():
    parser = argparse.ArgumentParser(description="Render params.yml for Color SSN nextflow pipeline")
    add_args(parser)
    return parser

def render_params(ssn_input, efi_config, efi_db, output_dir, job_id):
    params = {
        "output_dir": output_dir,
        "ssn_input": ssn_input,
        "efi_config": efi_config,
        "efi_db": efi_db
    }
    params_file = os.path.join(output_dir, "params.yml")
    with open(params_file, "w") as f:
        json.dump(params, f, indent=4)
    print(f"Wrote params to '{params_file}'")
    return params_file

if __name__ == "__main__":
    args = check_args(create_parser().parse_args())
    render_params(**vars(args))