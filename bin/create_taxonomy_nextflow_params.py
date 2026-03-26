#!/usr/bin/env python3

import argparse
import glob
import json
import os

import shared_args

NXF_SCRIPT = "pipelines/taxonomy/taxonomy.nf"

def add_args(parser: argparse.ArgumentParser):
    """
    Add global arguments and subparsers to ``parser``
    """
    # General parameters
    common_parser = argparse.ArgumentParser(add_help=False)
    common_parser.add_argument("--sequence-version", type=str, choices=["uniprot", "uniref90", "uniref50"])
    common_parser.add_argument("--filter", action="append", type=str, help="Filter sequences, use multiple times to indicate filter types")
    common_parser.add_argument("--input-file", type=str, help="Input file containing the information needed to gather sequences. Used in ACCESSIONS, BLAST, and FASTA import modes.")
    common_parser.add_argument("--families", type=str, help="Comma-separated list of families to add")
    shared_args.add_args(common_parser)

    # Add a subparser for each import mode
    subparsers = parser.add_subparsers(dest="import_mode", required=True)

    # Option B: Family
    family_parser = subparsers.add_parser("family", help="Import sequences using the family option", parents=[common_parser]).add_argument_group("Family Options")

    # Option C: FASTA
    fasta_parser = subparsers.add_parser("fasta", help="Import sequences using the FASTA option", parents=[common_parser]).add_argument_group("FASTA Options")

    # Option D: Accession IDs
    accession_parser = subparsers.add_parser("accessions", help="Import sequences using the Accession option", parents=[common_parser]).add_argument_group("Accession ID Options")

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    """
    Test file path and rewrite them to be absolute. Ensures target directory
    exists and is empty. Modifies ``args`` parameter
    """
    fail = False

    # Check for shared args validity
    validated_args = shared_args.check_args(args)
    if validated_args is None:
        fail = True
    else:
        args = validated_args

    # Handle a sequence-specifying input file for BLAST, ACCESSION, and FASTA input modes
    if args.input_file and not os.path.exists(args.input_file):
        print(f"Input file for sequence importing '{args.input_file}' does not exist")
        fail = True
    elif args.input_file:
        args.input_file = os.path.abspath(args.input_file)

    if args.workflow_def is None:
        args.workflow_def = os.path.abspath(NXF_SCRIPT)

    # Can't validate in the argparse library because --family can be used in modes other family
    # and in that case it is optional; when mode is family then it is required so we validate here
    if args.import_mode == "family" and not args.families:
        print(f"Family mode requires --families argument")
        fail = True

    args.sequence_filter = args.filter
    del args.filter

    if fail:
        print("Failed to render params template")
        exit(1)

    return args

def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Render params.yml for Taxonomy nextflow pipeline", add_help=False)
    add_args(parser)
    return parser


def render_params(output_dir, import_mode, sequence_version, job_id, efi_config, fasta_db, efi_db,
                  families=None, sequence_filter=None, input_file=None, **kwargs: dict):
    params = {
        "final_output_dir": output_dir,
        "sequence_version": sequence_version,
        "filter": sequence_filter,
        "input_file": input_file,
        "job_id": job_id,
        "efi_config": efi_config,
        "efi_db": efi_db,
        "fasta_db": fasta_db,
        "import_mode": import_mode,
    }
    if families is not None:
        params |= {
            "families": families
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

