#!/usr/bin/env python3

import argparse
import glob
import json
import os

import shared_args

NXF_SCRIPT = "pipelines/cgfp/cgfpidentify.nf"
DEFAULT_MAX_MSA_SEQ = 750
DEFAULT_MIN_MSA_SEQ = 3

def add_args(parser: argparse.ArgumentParser):
    """
    Add arguments for CGFP-Identify pipeline to ``parser``
    """
    parser.add_argument("--ssn-input", required=True, type=str, help="The SSN file to use as input to the CGFP-Identify pipeline, XGMML or zipped XGMML")
    parser.add_argument("--fasta-db", type=str, required=True, help="FASTA file or BLAST database to retrieve sequences from")
    parser.add_argument("--search-method", type=str, choices=["diamond", "blast"])
    parser.add_argument("--cdhit-sid", type=float, required=False, default=0.85, help="The sequence identity parameter for determining ShrotBRED consensus sequence families, ranging between 0 and 1")
    parser.add_argument("--ref-fasta-db", type=str, required=True, help="Path to reference database used to evaluate markers")
    shared_args.add_args(parser)

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    """
    Validate arguments and test file paths and rewrite them to be absolute
    """
    fail = False

    # Check for shared args validity
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

    if len(glob.glob(f"{args.ref_fasta_db}.*")) == 0:
        print(f"Reference FASTA database '{args.ref_fasta_db}' not found")
        fail = True

    if args.workflow_def is None:
        args.workflow_def = os.path.abspath(NXF_SCRIPT)

    if fail:
        print("Failed to render params template")
        exit(1)
    else:
        args.ssn_input = os.path.abspath(args.ssn_input)
        args.fasta_db = os.path.abspath(args.fasta_db)
        args.ref_fasta_db = os.path.abspath(args.ref_fasta_db)
        return args
    
def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Render params.yml for CGFP Identify nextflow pipeline")
    add_args(parser)
    return parser

def render_params(ssn_input, efi_config, efi_db, fasta_db, output_dir,
        search_method, cdhit_sid, ref_fasta_db,
        **kwargs: dict):
    params = {
        "final_output_dir": output_dir,
        "ssn_input": ssn_input,
        "fasta_db": fasta_db,
        "efi_config": efi_config,
        "efi_db": efi_db,
        "sb_search_refdb": ref_fasta_db,
        "sb_cdhit_sid": cdhit_sid,
        "sb_identify_method": search_method,
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

