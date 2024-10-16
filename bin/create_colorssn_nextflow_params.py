#!/usr/bin/env python3

import argparse
import glob
import json
import os

def add_args(parser: argparse.ArgumentParser):
    """
    add argumdents for Color SSN pipeline to ``parser``
    """
    parser.add_argument("--final-output-dir", required=True, type=str, help="Location for results. Will be created if it does not exist")
    parser.add_argument("--ssn-input", required=True, type=str, help="The SSN file to color, XGMML or zipped XGMML")
    parser.add_argument("--efi-config", required=True, type=str, help="Location of the EFI config file")
    parser.add_argument("--efi-db", required=True, type=str, help="Name of the MySQL database to use (e.g. efi_202406) or name of the SQLite file")
    parser.add_argument("--fasta-db", type=str, required=True, help="FASTA file or BLAST database to retrieve sequences from")
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
    
    if len(glob.glob(f"{args.fasta_db}.*")) == 0:
        print(f"FASTA database '{args.fasta_db}' not found")
        fail = True

    if os.path.exists(args.final_output_dir):
        if len(os.listdir(args.final_output_dir)) > 0:
            print(f"Output directory '{args.final_output_dir}' is not empty, refusing to create params.yml")
            fail = True
    else:
        try:
            os.makedirs(args.final_output_dir)
        except Exception as e:
            print(f"Could not create output directory '{args.final_output_dir}': {e}")
            fail = True


    if fail:
        print("Failed to render params template")
        exit(1)
    else:
        args.final_output_dir = os.path.abspath(args.final_output_dir)
        args.ssn_input = os.path.abspath(args.ssn_input)
        args.efi_config = os.path.abspath(args.efi_config)
        args.fasta_db = os.path.abspath(args.fasta_db)
        if os.path.exists(args.efi_db):
            args.efi_db = os.path.abspath(args.efi_db)
        return args
    
def create_parser():
    parser = argparse.ArgumentParser(description="Render params.yml for Color SSN nextflow pipeline")
    add_args(parser)
    return parser

def render_params(ssn_input, efi_config, efi_db, fasta_db, final_output_dir, job_id):
    params = {
        "final_output_dir": final_output_dir,
        "ssn_input": ssn_input,
        "fasta_db": fasta_db,
        "efi_config": efi_config,
        "efi_db": efi_db
    }
    params_file = os.path.join(final_output_dir, "params.yml")
    with open(params_file, "w") as f:
        json.dump(params, f, indent=4)
    print(f"Wrote params to '{params_file}'")
    return params_file

if __name__ == "__main__":
    args = check_args(create_parser().parse_args())
    render_params(**vars(args))
