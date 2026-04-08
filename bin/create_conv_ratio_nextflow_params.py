#!/usr/bin/env python3

import argparse
import glob
import json
import os

import shared_args

NXF_SCRIPT = "pipelines/convergenceratio/convergenceratio.nf"

def add_args(parser: argparse.ArgumentParser):
    """
    Add arguments for Convergence Ratio pipeline to ``parser``
    """
    parser.add_argument("--ascore", required=False, type=int, default=5, help="The alignment score to use for the BLAST computations; this is converted to an e-value")
    parser.add_argument("--colored-ssn-input", required=True, type=str, help="The SSN file to use for computing convergence ratios; must be the output of the Color SSN or Cluster Analysis pipelines")
    parser.add_argument("--fasta-db", type=str, required=True, help="FASTA file or BLAST database to retrieve sequences from")
    shared_args.add_args(parser)

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    """
    Test file paths and rewrite them to be absolute
    """
    fail = False

    # Check for shared args validity
    validated_args = shared_args.check_args(args)
    if validated_args is None:
        fail = True
    else:
        args = validated_args

    if not os.path.exists(args.colored_ssn_input):
        print(f"SSN Input file '{args.colored_ssn_input}' does not exist")
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
        args.colored_ssn_input = os.path.abspath(args.colored_ssn_input)
        args.fasta_db = os.path.abspath(args.fasta_db)
        return args

def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Render params.yml for GND nextflow pipeline")
    add_args(parser)
    return parser

def render_params(colored_ssn_input, ascore, efi_config, efi_db, fasta_db, output_dir, **kwargs: dict):
    evalue = f"1e-{ascore}"
    params = {
        "blast_evalue": evalue,
        "efi_config": efi_config,
        "efi_db": efi_db,
        "fasta_db": fasta_db,
        "final_output_dir": output_dir,
        "ssn_input": colored_ssn_input,
    }

    # Handle kwargs dict, assuming each entry is a parameter to be added to params
    params.update(kwargs)

    # Remove parameter keys with None values
    params = {key: value for key, value in params.items() if value != None}

    params_file = os.path.join(output_dir, shared_args.PARAMS_NAME)
    with open(params_file, "w") as f:
        json.dump(params, f, indent=4)
    print(f"Wrote params to '{params_file}'")
    return params_file

if __name__ == "__main__":
    args = check_args(create_parser().parse_args())
    params_file = render_params(**vars(args))
    shared_args.save_run_script(args, workflow_def=args.workflow_def, params_file=params_file)

