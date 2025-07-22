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
    # general parameters
    common_parser = argparse.ArgumentParser(add_help=False)
    common_parser.add_argument("--duckdb-memory-limit", default="8GB", type=str, help="Soft limit on DuckDB memory usage")
    common_parser.add_argument("--duckdb-threads", default=1, type=int, help="Number of threads DuckDB can use. More threads means higher memory usage")
    common_parser.add_argument("--fasta-shards", default=128, type=int, help="Number of files to split FASTA into. File is split so that BLAST can be parallelized")
    common_parser.add_argument("--accession-shards", default=16, type=int, help="Number of files to split Accessions list into. File is split so that sequence retrieval can be parallelized")
    common_parser.add_argument("--fasta-db", type=str, required=True, help="FASTA file or BLAST database to retrieve sequences from")
    common_parser.add_argument("--multiplex", action="store_true", help="Use CD-HIT to reduce the number of sequences used in analysis")
    common_parser.add_argument("--blast-num-matches", default=250, type=int, help="Maximum number of matches returned by BLAST for the all-by-all computation")
    common_parser.add_argument("--blast-evalue", default="1e-5", help="Cutoff E value to use in all-by-all BLAST")
    common_parser.add_argument("--sequence-version", type=str, default="uniprot", choices=["uniprot", "uniref90", "uniref50"])
    common_parser.add_argument("--filter", action="append", type=str, help="Filter sequences, use multiple times to indicate filter types")
    common_parser.add_argument("--families", type=str, help="Comma-separated list of families to add")
    common_parser.add_argument("--domain", choices=["central", "n-terminal", "c-terminal"], type=str, help="Trim sequences to domain boundaries")
    shared_args.add_args(common_parser)

    # add a subparser for each import mode
    subparsers = parser.add_subparsers(dest="import_mode", required=True)
    
    # option A: Sequence BLAST
    blast_parser = subparsers.add_parser("blast", help="Import sequences using the single sequence BLAST option", parents=[common_parser]).add_argument_group("Sequence BLAST Options")
    blast_parser.add_argument("--blast-query-file", required=True, type=str, help="The file containing a single sequence to use for the initial BLAST to obtain sequences")
    blast_parser.add_argument("--import-blast-fasta-db", type=str, help="FASTA file or BLAST database to use for the initial import to find sequences; must be set if the --sequence-version is uniref50 or uniref90; defaults to the same as --fasta-db.")
    blast_parser.add_argument("--import-blast-num-matches", default=1000, type=int, help="Maximum number of matches returned by BLAST when retrieving sequences")
    blast_parser.add_argument("--import-blast-evalue", default="1e-5", help="Cutoff e-value to use in the BLAST sequence alignment when retrieving sequences")

    # option B: Family
    family_parser = subparsers.add_parser("family", help="Import sequences using the family option", parents=[common_parser]).add_argument_group("Family Options")
    # Can add families to every job type

    # option C: FASTA
    fasta_parser = subparsers.add_parser("fasta", help="Import sequences using the FASTA option", parents=[common_parser]).add_argument_group("FASTA Options")
    fasta_parser.add_argument("--fasta-file", required=True, type=str, help="The FASTA file to read sequences from")

    # option D: Accession IDs
    accession_parser = subparsers.add_parser("accessions", help="Import sequences using the Accession option", parents=[common_parser]).add_argument_group("Accession ID Options")
    accession_parser.add_argument("--accessions-file", required=True, type=str, help="The list of Accession IDs to pull sequences for, one per line")
    accession_parser.add_argument("--domain-family", type=str, help="Family to use when trimming sequences to domain boundaries")

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    """
    Test file path and rewrite them to be absolute. Ensures target directory
    exists and is empty. Modifies ``args`` parameter
    """
    fail = False

    # check for shared args validity
    validated_args = shared_args.check_args(args)
    if validated_args is None:
        fail = True
    else:
        args = validated_args

    if len(glob.glob(f"{args.fasta_db}.*")) == 0:
        print(f"FASTA database '{args.fasta_db}' not found")
        fail = True

    # import mode-specific tests
    if args.import_mode == "blast":
        if not os.path.exists(args.blast_query_file):
            print(f"BLAST query file '{args.blast_query_file}' does not exist")
            fail = True
        else:
            args.blast_query_file = os.path.abspath(args.blast_query_file)
        if args.import_blast_fasta_db is not None:
            # Use the UniRef database for the BLAST
            args.import_blast_fasta_db = os.path.abspath(args.import_blast_fasta_db)
        else:
            # Use the main database for the BLAST
            args.import_blast_fasta_db = os.path.abspath(args.fasta_db)
    elif args.import_mode == "fasta":
        if not os.path.exists(args.fasta_file):
            print(f"FASTA import mode: FASTA file '{args.fasta_file}' does not exist")
            fail = True
        else:
            args.fasta_file = os.path.abspath(args.fasta_file)
    elif args.import_mode == "accessions":
        if not os.path.exists(args.accessions_file):
            print(f"Accession ID list '{args.accessions_file}' does not exist")
            fail = True
        else:
            args.accessions_file = os.path.abspath(args.accessions_file)

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


def render_params(output_dir, duckdb_memory_limit, duckdb_threads, fasta_shards,
                  accession_shards, blast_num_matches, job_id, efi_config, fasta_db, efi_db, multiplex,
                  blast_evalue, import_mode, sequence_version,
                  families=None, sequence_filter=None, fasta_file=None, accessions_file=None,
                  blast_query_file=None, import_blast_fasta_db=None, import_blast_num_matches=None,
                  import_blast_evalue=None, domain=None, domain_family=None, **kwargs: dict):
    params = {
        "final_output_dir": output_dir,
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
        "multiplex": multiplex,
        "blast_num_matches": blast_num_matches,
        "blast_evalue": blast_evalue,
        "sequence_version": sequence_version
    }
    if import_mode == "blast":
        params |= {
            "blast_query_file": blast_query_file,
            "import_blast_fasta_db": import_blast_fasta_db,
            "import_blast_num_matches": import_blast_num_matches,
            "import_blast_evalue": import_blast_evalue
        }
    elif import_mode == "fasta":
        params |= {
            "uploaded_fasta_file": fasta_file
        }
    elif import_mode == "accessions":
        params |= {
            "accessions_file": accessions_file
        }

    if families is not None:
        params |= {
            "families": families
        }

    if domain is not None:
        params |= {
            "domain": domain
        }
        if import_mode == "accessions" and domain_family is not None:
            params |= {
                "domain_family": domain_family
            }

    params_file = os.path.join(output_dir, shared_args.PARAMS_NAME)
    with open(params_file, "w") as f:
        json.dump(params, f, indent=4)
    print(f"Wrote params to '{params_file}'")
    return params_file

if __name__ == "__main__":
    args = check_args(create_parser().parse_args())
    params_file = render_params(**vars(args))
    shared_args.save_run_script(args, workflow_def=args.workflow_def, params_file=params_file)

