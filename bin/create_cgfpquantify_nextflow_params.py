#!/usr/bin/env python3

import argparse
import glob
import json
import os

import shared_args

NXF_SCRIPT = "pipelines/cgfp/cgfpquantify.nf"
DEFAULT_MAX_MSA_SEQ = 750
DEFAULT_MIN_MSA_SEQ = 3

def add_args(parser: argparse.ArgumentParser):
    """
    Add arguments for CGFP-Quantify pipeline to ``parser``
    """
    parser.add_argument("--identify-dir", required=True, type=str, help="The directory containing CGFP-Identify results")
    parser.add_argument("--metagenome-db-dir", required=True, type=str, help="Path to the metagenome database directory; must contain db.list and db.config files describing the database")
    parser.add_argument("--metagenome-ids", type=str, required=True, help="Comma separated list of metagenome IDs to use in quantify analysis")
    parser.add_argument("--search-method", type=str, choices=["diamond", "blast"])
    parser.add_argument("--shortbred-src", type=str, required=True, help="Path to base ShortBRED source directory, cloned from EFI repository")
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

    if not os.path.exists(args.identify_dir):
        print(f"Input CGFP-Identify results dir '{args.identify_dir}' does not exist")
        fail = True

    if len(glob.glob(f"{args.metagenome_db}/*")) == 0:
        print(f"Metagenome database '{args.metagenome_db}' not found")
        fail = True

    args.metagenome_db_dir = os.path.abspath(args.metagenome_db_dir)
    args.identify_dir = os.path.abspath(args.identify_dir)

    args.shortbred_src = os.path.abspath(args.shortbred_src)

    args.ssn_input = os.path.join(args.identify_dir, "marker_ssn.xgmml")

    args.metagenome_ids = args.metagenome_ids.split(",")

    if args.workflow_def is None:
        args.workflow_def = os.path.abspath(NXF_SCRIPT)

    if fail:
        print("Failed to render params template")
        exit(1)
    else:
        return args
    
def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Render params.yml for CGFP Quantify nextflow pipeline")
    add_args(parser)
    return parser

def render_params(efi_config, efi_db, output_dir, metagenome_db_dir,
        identify_dir, ssn_input, search_method, shortbred_src,
        **kwargs: dict):
    params = {
        "final_output_dir": output_dir,
        "efi_config": efi_config,
        "efi_db": efi_db,
        "sb_identify_method": search_method,
        "metagenome_db_dir": metagenome_db_dir,
        "identify_dir": identify_dir,
        "ssn_input": ssn_input,
        "shortbred_src_dir": shortbred_src,
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

