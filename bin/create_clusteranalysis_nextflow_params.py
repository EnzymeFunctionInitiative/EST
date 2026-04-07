#!/usr/bin/env python3

import argparse
import glob
import json
import os

import shared_args

NXF_SCRIPT = "pipelines/clusteranalysis/clusteranalysis.nf"
DEFAULT_MAX_MSA_SEQ = 750
DEFAULT_MIN_MSA_SEQ = 3

def add_args(parser: argparse.ArgumentParser):
    """
    Add arguments for Cluster Analysis SSN pipeline to ``parser``
    """
    parser.add_argument("--ssn-input", required=True, type=str, help="The SSN file to color, XGMML or zipped XGMML")
    parser.add_argument("--fasta-db", type=str, required=True, help="FASTA file or BLAST database to retrieve sequences from")
    parser.add_argument("--max-msa-seq", type=int, required=False, default=DEFAULT_MAX_MSA_SEQ, help="The maximum number of sequences to use when running the multiple sequence alignment; clusters larger than this number will be resampled to this value for the MSA")
    parser.add_argument("--min-msa-seq", type=int, required=False, default=DEFAULT_MIN_MSA_SEQ, help="The minimum number of sequences required for running the multiple sequence alignment; clusters smaller than this number will be excluded")
    parser.add_argument("--weblogo", action=argparse.BooleanOptionalAction, default=True, help="Generate a weblogo for each cluster (on by default)")
    parser.add_argument("--hmms", action=argparse.BooleanOptionalAction, default=True, help="Generate a HMM and Skylign data for each cluster (on by default)")
    parser.add_argument("--length-histo", action=argparse.BooleanOptionalAction, default=True, help="Generate length histograms for each cluster (on by default)")
    parser.add_argument("--compute-cons-res", action=argparse.BooleanOptionalAction, default=False, help="Generate consensus residues each cluster (on by default)")
    parser.add_argument("--residues", type=str, help="If --compute-cons-res is specified, then the conserved residue calculation will be performed for these comma-separated amino acid codes")
    parser.add_argument("--pid-thresholds", type=str, help="If --compute-cons-res is specified, then the conserved residues will be calculated at the given comma-separated list of percent identities")
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

    if args.workflow_def is None:
        args.workflow_def = os.path.abspath(NXF_SCRIPT)

    # Consensus residue computation is optional, but if specified it requires two additional arguments
    if args.compute_cons_res:
        if not args.residues or not args.pid_thresholds:
            print(f"Both --residues and --pid-threshold must be passed when --compute-cons-res is specified")
            fail = True

        if args.pid_thresholds:
            try:
                pid_list = [float(x.strip()) for x in args.pid_thresholds.split(',')]
                if any(x < 0 or x > 100 for x in pid_list):
                    print(f"--pid-threshold values must be >= 0 and <= 100")
                    fail = True
                args.pid_thresholds = pid_list
            except ValueError:
                print(f"--pid-threshold must be a comma-separated list of percentages from 0-100")
                fail = True

        if args.residues:
            r_list = [x.strip() for x in args.residues.split(',')]
            args.residues = r_list
    else:
        args.residues = ""
        args.pid_thresholds = []

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

def render_params(ssn_input, efi_config, efi_db, fasta_db, output_dir,
        max_msa_seq, min_msa_seq, weblogo, hmms, length_histo,
        compute_cons_res, residues, pid_thresholds,
        **kwargs: dict):
    params = {
        "final_output_dir": output_dir,
        "ssn_input": ssn_input,
        "fasta_db": fasta_db,
        "efi_config": efi_config,
        "efi_db": efi_db,
        "max_msa_sequences": max_msa_seq,
        "min_msa_sequences": min_msa_seq,
        "make_weblogos": weblogo,
        "make_hmms": hmms,
        "make_length_histograms": length_histo,
        "compute_conserved_residues": compute_cons_res,
        "conserved_residues": residues,
        "pid_thresholds": pid_thresholds,
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

