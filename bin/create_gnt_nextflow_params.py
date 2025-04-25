#!/usr/bin/env python3

import argparse
import glob
import json
import os

import shared_args

NXF_SCRIPT = "pipelines/gnt/gnt.nf"

def add_args(parser: argparse.ArgumentParser):
    """
    Add arguments for GNT pipeline to ``parser``
    """
    parser.add_argument("--ssn-input", required=True, type=str, help="The SSN file to color and compute GNNs for, XGMML or zipped XGMML")
    parser.add_argument("--fasta-db", type=str, required=True, help="FASTA file or BLAST database to retrieve sequences from")
    parser.add_argument("--nb-size", type=int, required=False, default=20, help="Optional number of neighbors on the left and right of the input IDs to include in the analysis, an integer > 0 and <= 20.")
    parser.add_argument("--cooc-threshold", type=float, required=False, default=0.20, help="Optional co-occurrence threshold to use for computing the Pfam hubs, a real number >= 0 and <= 1.")
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

    if args.nb_size < 1 or args.nb_size > 20:
        print(f"Invalid value for --nb-size ({args.nb_size}).")
        fail = True

    if args.cooc_threshold < 0 or args.cooc_threshold > 1:
        print(f"Invalid value for --cooc-threshold ({args.cooc_threshold}).")
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
    
def create_parser():
    parser = argparse.ArgumentParser(description="Render params.yml for GNT nextflow pipeline")
    add_args(parser)
    return parser

def render_params(ssn_input, efi_config, efi_db, fasta_db, nb_size, cooc_threshold, output_dir,
        **kwargs: dict):
    params = {
        "final_output_dir": output_dir,
        "ssn_input": ssn_input,
        "efi_config": efi_config,
        "efi_db": efi_db,
        "fasta_db": fasta_db,
        "nb_size": nb_size,
        "cooc_threshold": cooc_threshold
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


