import argparse
import json
import os

def add_args(parser):
    """
    add arguments for SSN pipeline parameters to ``parser``
    """
    # TODO: pass --est-output-dir to this tool and set some params based on files in there

    ssn_args_parser = argparse.ArgumentParser(add_help=False).add_argument_group("SSN Creation Options")
    ssn_args_parser.add_argument("--filter-parameter", default="alignment_score", choices=["pident", "alignment_length", "bitscore", "query_length", "subject_length", "alignment_score"], help="Parameter to filter edges on")
    ssn_args_parser.add_argument("--filter-min-val", required=True, type=float, help="Retain rows where filter-parameter >= this value")
    ssn_args_parser.add_argument("--min-length", default=0, help="Minimum required sequence length")
    ssn_args_parser.add_argument("--max-length", default=50000, help="Maximum sequence length to allow")
    ssn_args_parser.add_argument("--ssn-name", required=True, type=str, help="Name for the SSN file")
    ssn_args_parser.add_argument("--ssn-title", required=True, help="Title to be included as metadata in the XGMML file")
    ssn_args_parser.add_argument("--maxfull", default=0)

    # add a subparser for automatically populating from EST output dir
    subparsers = parser.add_subparsers(dest="mode", required=True)

    autoparam_parser = subparsers.add_parser("auto", help="Autopopulate SSN parameters from EST directory", parents=[ssn_args_parser]).add_argument_group("EST-related parameters")
    autoparam_parser.add_argument("--est-output-dir", type=str, required=True, help="The EST output directory to use for parameter autopopulation")


    manual_parser = subparsers.add_parser("manual", help="Manually specify parameters related to EST output", parents=[ssn_args_parser]).add_argument_group("EST-related parameters")
    manual_parser.add_argument("--blast-parquet", required=True, type=str, help="Parquet file representing edges from EST pipeline, usually called 1.out.parquet")
    manual_parser.add_argument("--fasta-file", required=True, type=str, help="FASTA file to create SSN from")
    manual_parser.add_argument("--output-dir", required=True, type=str, help="Location for results. Will be created if it does not exist")
    manual_parser.add_argument("--uniref-version", default="", choices=["", "90", "50"], help="Which database to use for annotations")
    manual_parser.add_argument("--efi-config", required=True, help="Location of the EFI config file")
    manual_parser.add_argument("--db-version", default=100, help="The temporal version of UniProt to use")
    manual_parser.add_argument("--job-id", default=131, help="Job ID")

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
        args.fasta_file = os.path.join(args.est_output_dir, "allsequences.fasta")
        args.output_dir = os.path.join(args.est_output_dir, f"ssn")
        parameter_file = os.path.join(args.est_output_dir, "params.yml")
        try:
            with open(parameter_file) as f:
                params = json.load(f)
                # args.uniref_version = params[""]
                args.efi_config = params["efi_config"]
                args.db_version = 1
                args.uniref_version = 1
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

    if os.path.exists(args.output_dir):
        if len(os.listdir(args.output_dir)) > 0:
            print(f"Output directory '{args.output_dir}' is not empty, refusing to create params.yml")
            fail = True
    else:
        try:
            os.makedirs(args.output_dir)
        except Exception as e:
            print(f"Could not create output directory '{args.output_dir}': {e}")
            fail = True

    if not os.path.exists(args.efi_config):
        print(f"EFI config file '{args.efi_config}' does not exist")
        fail = True

    if fail:
        print("Failed to render params template")
        exit(1)
    else:
        args.blast_parquet = os.path.abspath(args.blast_parquet)
        args.fasta_file = os.path.abspath(args.fasta_file)
        args.output_dir = os.path.abspath(args.output_dir)
        args.efi_config = os.path.abspath(args.efi_config)
        return args

def create_parser():
    parser = argparse.ArgumentParser(description="Render params.yml for SSN nextflow pipeline")
    add_args(parser)
    return parser

def render_params(blast_parquet, fasta_file, output_dir, filter_parameter, filter_min_val, min_length, max_length, ssn_name, ssn_title, maxfull, uniref_version, efi_config, db_version, job_id):
    params = {
        "blast_parquet": blast_parquet,
        "fasta_file": fasta_file,
        "final_output_dir": output_dir,
        "filter_parameter": filter_parameter,
        "filter_min_val": filter_min_val,
        "min_length": min_length,
        "max_length": max_length,
        "ssn_name": ssn_name,
        "ssn_title": ssn_title,
        "maxfull": maxfull,
        "uniref_version": uniref_version,
        "efi_config": efi_config,
        "db_version": db_version,
        "job_id": job_id
    }
    params_file = os.path.join(output_dir, "params.yml")
    with open(params_file, "w") as f:
        json.dump(params, f, indent=4)
    print(f"Wrote params to '{params_file}'")
    return params_file

if __name__ == "__main__":
    args = vars(check_args(create_parser().parse_args()))
    del args["est_output_dir"]
    del args["mode"]
    render_params(**args)
