#!/usr/bin/env python3

import argparse
import glob
import json
import os

import shared_args

NXF_SCRIPT = "pipelines/est/est.nf"

def add_args(parser: argparse.ArgumentParser):
    """
    Add global arguments and subparsers to ``parser``
    """
    # General parameters
    common_parser = argparse.ArgumentParser(add_help=False)
    common_parser.add_argument("--duckdb-memory-limit", type=str, help="Soft limit on DuckDB memory usage")
    common_parser.add_argument("--duckdb-threads", type=int, help="Number of threads DuckDB can use. More threads means higher memory usage")
    common_parser.add_argument("--fasta-shards", type=int, help="Number of files to split FASTA into. File is split so that BLAST can be parallelized")
    common_parser.add_argument("--accession-shards", type=int, help="Number of files to split Accessions list into. File is split so that sequence retrieval can be parallelized")
    common_parser.add_argument("--fasta-db", type=str, required=True, help="FASTA file or BLAST database to retrieve sequences from")
    common_parser.add_argument("--collapse-redundancy", action="store_true", help="Use CD-HIT to reduce the number of sequences used in analysis")
    common_parser.add_argument("--blast-num-matches", type=int, help="Maximum number of matches returned by BLAST for the all-by-all computation")
    common_parser.add_argument("--blast-evalue", help="Cutoff E value to use in all-by-all BLAST")
    common_parser.add_argument("--sequence-version", type=str, choices=["uniprot", "uniref90", "uniref50"])
    common_parser.add_argument("--filter", action="append", type=str, help="Filter sequences, use multiple times to indicate filter types")
    common_parser.add_argument("--families", type=str, help="Comma-separated list of families to add")
    common_parser.add_argument("--domain", action="store_true", help="Should sequences be trimmed to domain boundaries?")
    common_parser.add_argument("--domain-region", choices=["domain", "n-terminal", "c-terminal"], type=str, help="Trim sequences to domain boundaries")
    common_parser.add_argument("--input-file", type=str, help="Input file containing the information needed to gather sequences. Used in ACCESSIONS, BLAST, and FASTA import modes.")
    shared_args.add_args(common_parser)

    # Add a subparser for each import mode
    subparsers = parser.add_subparsers(dest="import_mode", required=True)

    # Option A: Sequence BLAST
    blast_parser = subparsers.add_parser("blast", help="Import sequences using the single sequence BLAST option", parents=[common_parser]).add_argument_group("Sequence BLAST Options")
    blast_parser.add_argument("--import-blast-fasta-db", type=str, help="FASTA file or BLAST database to use for the initial import to find sequences; must be set if the --sequence-version is uniref50 or uniref90; defaults to the same as --fasta-db.")
    blast_parser.add_argument("--import-blast-num-matches", type=int, help="Maximum number of matches returned by BLAST when retrieving sequences")
    blast_parser.add_argument("--import-blast-evalue", help="Cutoff e-value to use in the BLAST sequence alignment when retrieving sequences")

    # Option B: Family
    family_parser = subparsers.add_parser("family", help="Import sequences using the family option", parents=[common_parser]).add_argument_group("Family Options")
    # Can add families to every job type

    # Option C: FASTA
    fasta_parser = subparsers.add_parser("fasta", help="Import sequences using the FASTA option", parents=[common_parser]).add_argument_group("FASTA Options")

    # Option D: Accession IDs
    accession_parser = subparsers.add_parser("accessions", help="Import sequences using the Accession option", parents=[common_parser]).add_argument_group("Accession ID Options")
    accession_parser.add_argument("--domain-family", type=str, help="Family to use when trimming sequences to domain boundaries")

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

    if len(glob.glob(f"{args.fasta_db}.*")) == 0:
        print(f"FASTA database '{args.fasta_db}' not found")
        fail = True

    # Import mode-specific tests
    if args.import_mode == "blast":
        if args.import_blast_fasta_db is not None:
            # Use the UniRef database for the BLAST
            args.import_blast_fasta_db = os.path.abspath(args.import_blast_fasta_db)
        else:
            # Use the main database for the BLAST
            args.import_blast_fasta_db = os.path.abspath(args.fasta_db)

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
    else:
        args.fasta_db = os.path.abspath(args.fasta_db)
        return args

def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Render params.yml for EST nextflow pipeline", add_help=False)
    add_args(parser)
    return parser


def render_params(output_dir, import_mode, sequence_version, job_id, efi_config, fasta_db, efi_db,
                  duckdb_memory_limit=None, duckdb_threads=None, fasta_shards=None,
                  accession_shards=None, blast_num_matches=None, collapse_redundancy=None,
                  blast_evalue=None, domain=None, families=None, sequence_filter=None,
                  input_file=None, import_blast_fasta_db=None, import_blast_num_matches=None,
                  import_blast_evalue=None, domain_region=None, domain_family=None,
                  **kwargs: dict):
    params = {
        "final_output_dir": output_dir,
        "input_file": input_file,
        "duckdb_memory_limit": duckdb_memory_limit,
        "duckdb_threads": duckdb_threads,
        "num_fasta_shards": fasta_shards,
        "num_accession_shards": accession_shards,
        "job_id": job_id,
        "efi_config": efi_config,
        "fasta_db": fasta_db,
        "efi_db": efi_db,
        "import_mode": import_mode,
        "filter": sequence_filter,
        "multiplex": collapse_redundancy,
        "blast_num_matches": blast_num_matches,
        "blast_evalue": blast_evalue,
        "sequence_version": sequence_version,
        "domain": domain,
    }
    if import_mode == "blast":
        params |= {
            "import_blast_fasta_db": import_blast_fasta_db,
            "import_blast_num_matches": import_blast_num_matches,
            "import_blast_evalue": import_blast_evalue
        }

    if families is not None:
        params |= {
            "families": families
        }

    if domain and domain_region is not None:
        params |= {
            "domain_region": domain_region
        }
        if import_mode == "accessions" and domain_family is not None:
            params |= {
                "domain_family": domain_family
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

