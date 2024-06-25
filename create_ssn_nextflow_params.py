import argparse
import json
import os
import string

def add_args(parser):
    # TODO: pass --est-output-dir to this tool and set some params based on files in there
    parser.add_argument("--blast-parquet", required=True, type=str, help="Parquet file representing edges from EST pipeline, usually called 1.out.parquet")
    parser.add_argument("--fasta-file", required=True, type=str, help="FASTA file to create SSN from")
    parser.add_argument("--output-dir", required=True, type=str, help="Location for results. Will be created if it does not exist")
    parser.add_argument("--filter-parameter", default="alignment_score", choices=["pident", "alignment_length", "bitscore", "query_length", "subject_length", "alignment_score"], help="Parameter to filter edges on")
    parser.add_argument("--filter-min-val", required=True, type=float, help="Retain rows where filter-parameter >= this value")
    parser.add_argument("--min-length", default=0, help="Minimum required sequence length")
    parser.add_argument("--max-length", default=50000, help="Maximum sequence length to allow")
    parser.add_argument("--ssn-name", required=True, type=str, help="Name for the SSN file")
    parser.add_argument("--ssn-title", required=True, help="Title to be included as metadata in the XGMML file")
    parser.add_argument("--maxfull", default=0)
    parser.add_argument("--uniref-version", default="", choices=["", "90", "50"], help="Which database to use for annotations")
    parser.add_argument("--efi-config", required=True, help="Location of the EFI config file")
    parser.add_argument("--db-version", default=99, help="The temporal version of UniProt to use")


def parse_args():
    parser = argparse.ArgumentParser(description="Render params.yml for SSN nextflow pipeline")
    add_args(parser)
    args = parser.parse_args()

    fail = False
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

def render_params(blast_parquet, fasta_file, output_dir, filter_parameter, filter_min_val, min_length, max_length, ssn_name, ssn_title, maxfull, uniref_version, efi_config, db_version):
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
        "db_version": db_version
    }
    params_file = os.path.join(output_dir, "params.yml")
    with open(params_file, "w") as f:
        json.dump(params, f, indent=4)
    print(f"Wrote params to '{params_file}'")

if __name__ == "__main__":
    args = parse_args()
    render_params(**vars(args))
