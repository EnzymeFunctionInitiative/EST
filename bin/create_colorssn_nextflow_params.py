#!/usr/bin/env python3

import argparse
import glob
import json
import os

import shared_args

NXF_SCRIPT = "pipelines/colorssn/colorssn.nf"

def add_args(parser: argparse.ArgumentParser):
    """
    Add arguments for Color SSN pipeline to ``parser``
    """
    parser.add_argument("--ssn-input", required=True, type=str, help="The SSN file to color, XGMML or zipped XGMML")
    parser.add_argument("--fasta-db", type=str, required=True, help="FASTA file or BLAST database to retrieve sequences from")
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

    if not os.path.exists(args.ssn_input):
        print(f"SSN Input file '{args.ssn_input}' does not exist")
        fail = True
    
    if len(glob.glob(f"{args.fasta_db}.*")) == 0:
        print(f"FASTA database '{args.fasta_db}' not found")
        fail = True

    if args.workflow_def is None:
        args.workflow_def = os.path.abspath(NXF_SCRIPT)

    if fail:
        print("Failed to render params template")
        exit(1)
    else:
        args.ssn_input = os.path.abspath(args.ssn_input)
        args.fasta_db = os.path.abspath(args.fasta_db)
        return args
    
def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Render params.yml for Color SSN nextflow pipeline")
    add_args(parser)
    return parser

def render_params(ssn_input, efi_config, efi_db, fasta_db, output_dir, **kwargs: dict):
    params = {
        "final_output_dir": output_dir,
        "ssn_input": ssn_input,
        "fasta_db": fasta_db,
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
    params_file = render_params(**vars(args))
    shared_args.save_run_script(args, workflow_def=args.workflow_def, params_file=params_file)

