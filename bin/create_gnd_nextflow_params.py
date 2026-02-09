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
    parser.add_argument("--import-mode", required=True, type=str, choices=["blast", "fasta", "accessions"], help="Mode corresponding to input data type")
    parser.add_argument("--input-file", required=True, type=str, help="Input file containing the sequence ID data (accession IDs, FASTA, sequence for BLAST) required for generating the GND")
    parser.add_argument("--nb-size", type=int, required=False, help="Optional number of neighbors on the left and right of the input IDs to include in the analysis, an integer > 0 and <= 20.")
    parser.add_argument("--fasta-db", type=str, help="FASTA file or BLAST database to retrieve sequences from")
    parser.add_argument("--import-blast-fasta-db", type=str, help="FASTA file or BLAST database to use for the initial import to find sequences; must be set if the --sequence-version is uniref50 or uniref90; defaults to the same as --fasta-db.")
    parser.add_argument("--import-blast-num-matches", type=int, help="Maximum number of matches returned by BLAST when retrieving sequences")
    parser.add_argument("--import-blast-evalue", help="Cutoff e-value to use in the BLAST sequence alignment when retrieving sequences")
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

    if not os.path.exists(args.input_file):
        print(f"Input file '{args.input_file}' does not exist")
        fail = True
    else:
        args.input_file = os.path.abspath(args.input_file)

    if args.import_mode == "blast":
        if args.import_blast_fasta_db is None:
            print(f"When --import-mode is blast, --import-blast-fasta-db must be specified")
            fail = True
    
    if args.nb_size and (
        args.nb_size < 1 or args.nb_size > 20
    ):
        print(f"Invalid value for --nb-size ({args.nb_size}).")
        fail = True

    if args.workflow_def is None:
        args.workflow_def = os.path.abspath(NXF_SCRIPT)

    if fail:
        print("Failed to render params template")
        exit(1)
    else:
        return args
    
def create_parser():
    parser = argparse.ArgumentParser(description="Render params.yml for GND nextflow pipeline")
    add_args(parser)
    return parser

def render_params(import_mode, input_file, efi_config, efi_db, output_dir,
        import_blast_fasta_db = None, import_blast_num_matches = None, import_blast_evalue = None,
        nb_size=None, **kwargs: dict):
    params = {
        "final_output_dir": output_dir,
        "import_mode": import_mode,
        "input_file": input_file,
        "efi_config": efi_config,
        "efi_db": efi_db,
        "nb_size": nb_size,
        "import_blast_fasta_db": import_blast_fasta_db,
        "import_blast_num_matches": import_blast_num_matches,
        "import_blast_evalue": import_blast_evalue,
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

