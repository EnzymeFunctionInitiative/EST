#!/usr/bin/env python3

import argparse
import json
import os

import shared_args

NXF_SCRIPT = "pipelines/generatessn/generatessn.nf"

def add_args(parser):
    """
    Add arguments for SSN pipeline parameters to ``parser``
    """
    # SSN creation parameters
    ssn_args_parser = argparse.ArgumentParser(add_help=False).add_argument_group("SSN Creation Options")
    ssn_args_parser.add_argument("--threshold-metric", choices=["pident", "alignment_length", "bitscore", "query_length", "subject_length", "alignment_score"], default="alignment_score", help="Parameter to filter edges on")
    ssn_args_parser.add_argument("--threshold-min-val", required=True, type=float, help="Retain rows where threshold metric >= this value")
    ssn_args_parser.add_argument("--filter", action="append", type=str, help="Filter sequences, use multiple times to indicate filter types")
    ssn_args_parser.add_argument("--min-length", help="Minimum required sequence length")
    ssn_args_parser.add_argument("--max-length", help="Maximum sequence length to allow")
    ssn_args_parser.add_argument("--ssn-name", required=True, type=str, help="Name for the SSN file")
    ssn_args_parser.add_argument("--job-name", required=True, help="Title to be included as metadata in the XGMML file")
    ssn_args_parser.add_argument("--maxfull", default=0)

    # Add a subparser for automatically populating from EST output dir
    subparsers = parser.add_subparsers(dest="mode", required=True)

    # automatically pull parameters from EST results and params file
    autoparam_parser = subparsers.add_parser("auto", help="Autopopulate SSN parameters from EST directory", parents=[ssn_args_parser]).add_argument_group("EST-related parameters")
    autoparam_parser.add_argument("--est-output-dir", type=str, required=True, help="The EST output directory to use for parameter autopopulation")
    shared_args.add_args(autoparam_parser, use_output_dir=False)

    # If not in auto mode, manually specify the location of the results files
    manual_parser = subparsers.add_parser("manual", help="Manually specify parameters related to EST output", parents=[ssn_args_parser]).add_argument_group("EST-related parameters")
    manual_parser.add_argument("--blast-parquet", required=True, type=str, help="Parquet file representing edges from EST pipeline, usually called 1.out.parquet")
    manual_parser.add_argument("--fasta-file", required=True, type=str, help="FASTA file to create SSN from")
    manual_parser.add_argument("--seq-meta-file", required=True, type=str, help="EST sequence metadata file to get basic metadata from")
    manual_parser.add_argument("--source-ids-file", required=True, type=str, help="EST accession ID table file to get IDs from, for filtering")
    manual_parser.add_argument("--db-version", default=100, help="Indicates the version of the EFI database that was used to generate the network")
    shared_args.add_args(manual_parser)

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    """
    Test file path and rewrite them to be absolute. Ensures target directory
    exists and is empty. Modifies ``args`` parameter
    """
    fail = False

    if args.mode == "auto":
        if not os.path.exists(args.est_output_dir):
            print(f"EST output directory '{args.est_output_dir}' does not exist, failed to render params file")
            exit(1)
        args.blast_parquet = os.path.join(args.est_output_dir, "1.out.parquet")
        args.fasta_file = os.path.join(args.est_output_dir, "all_sequences.fasta")
        args.output_dir = os.path.join(args.est_output_dir, f"ssn")
        args.seq_meta_file = os.path.join(args.est_output_dir, "sequence_metadata.tab")
        args.source_ids_file = os.path.join(args.est_output_dir, "accession_table.tab")
        parameter_file = os.path.join(args.est_output_dir, "params.yml")
        try:
            with open(parameter_file) as f:
                params = json.load(f)
                args.efi_config = params["efi_config"]
                args.efi_db = params["efi_db"]
                #TODO: figure out how to get this from the EST run
                args.db_version = 1
                args.job_id = params["job_id"]
        except (FileNotFoundError, PermissionError) as e:
            print(f"Could not open parameter file '{parameter_file}': {e.strerror}")
            fail = True
        except KeyError as e:
            print(f"Failed to find key '{e.args}' in params file '{parameter_file}'")
            fail = True

    if not os.path.exists(args.blast_parquet):
        print(f"BLAST Parquet '{args.blast_parquet}' does not exist")
        fail = True

    if not os.path.exists(args.fasta_file):
        print(f"FASTA file '{args.fasta_file}' does not exist")
        fail = True

    if not os.path.exists(args.seq_meta_file):
        print(f"Sequence metadata file '{args.seq_meta_file}' does not exist")
        fail = True

    if not os.path.exists(args.source_ids_file):
        print(f"Source accession IDs table file '{args.source_ids_file}' does not exist")
        fail = True

    # Check for shared args validity
    validated_args = shared_args.check_args(args)
    if validated_args is None:
        fail = True
    else:
        args = validated_args

    # Need to store this as 'sequence_filter' because 'filter' is a reserved keyword in some
    # contexts and can't be used in a function definition
    args.sequence_filter = args.filter
    del args.filter

    if args.workflow_def is None:
        args.workflow_def = os.path.abspath(NXF_SCRIPT)

    if fail:
        print("Failed to render params template")
        exit(1)
    else:
        args.blast_parquet = os.path.abspath(args.blast_parquet)
        args.fasta_file = os.path.abspath(args.fasta_file)
        args.seq_meta_file = os.path.abspath(args.seq_meta_file)
        args.source_ids_file = os.path.abspath(args.source_ids_file)
        return args

def create_parser():
    parser = argparse.ArgumentParser(description="Render params.yml for SSN nextflow pipeline")
    add_args(parser)
    return parser

def render_params(blast_parquet, fasta_file, source_ids_file, seq_meta_file, output_dir,
        efi_config, db_version, job_id, efi_db, mode, ssn_name, job_name, maxfull,
        threshold_min_val,
        threshold_metric=None, min_length=None, max_length=None, sequence_filter=None,
        **kwargs: dict):
    params = {
        "blast_parquet": blast_parquet,
        "fasta_file": fasta_file,
        "source_ids_file": source_ids_file,
        "seq_meta_file": seq_meta_file,
        "final_output_dir": output_dir,
        "threshold_metric": threshold_metric,
        "threshold_min_val": threshold_min_val,
        "min_length": min_length,
        "max_length": max_length,
        "filter": sequence_filter,
        "ssn_name": ssn_name,
        "job_name": job_name,
        "maxfull": maxfull,
        "efi_config": efi_config,
        "db_version": db_version,
        "job_id": job_id,
        "efi_db": efi_db,
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

