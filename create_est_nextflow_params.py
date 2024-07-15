import argparse
import glob
import json
import os

def add_args(parser: argparse.ArgumentParser):
    """
    Add global arguments and subparsers to ``parser``
    """
    # general parameters
    common_parser = argparse.ArgumentParser(add_help=False)
    common_parser.add_argument("--output-dir", required=True, type=str, help="Location for results. Will be created if it does not exist")
    common_parser.add_argument("--duckdb-memory-limit", default="8GB", type=str, help="Soft limit on DuckDB memory usage")
    common_parser.add_argument("--duckdb-threads", default=1, type=int, help="Number of threads DuckDB can use. More threads means higher memory usage")
    common_parser.add_argument("--fasta-shards", default=128, type=int, help="Number of files to split FASTA into. File is split so that BLAST can be parallelized")
    common_parser.add_argument("--accession-shards", default=16, type=int, help="Number of files to split Accessions list into. File is split so that sequence retrieval can be parallelized")
    common_parser.add_argument("--blast-matches", default=250, type=int, help="Number of matches BLAST should return")
    common_parser.add_argument("--job-id", default=131, help="ID used when running on the EFI website. Not important otherwise")
    common_parser.add_argument("--efi-config", required=True, type=str, help="EFI configuration file path")
    common_parser.add_argument("--fasta-db", type=str, required=True, help="FASTA file or BLAST database to retrieve sequences from")
    common_parser.add_argument("--efi-db", required=True, type=str, help="Name of the MySQL database to use (e.g. efi_202406) or name of the SQLite file")
    common_parser.add_argument("--multiplex", action="store_true", help="Use CD-HIT to reduce the number of sequences used in analysis")
    common_parser.add_argument("--blast-evalue", default="1e-5", help="Cutoff E value to use in all-by-all BLAST")
    common_parser.add_argument("--sequence-version", type=str, default="uniprot", choices=["uniprot", "uniref90", "uniref50"])


    # add a subparser for each import mode
    subparsers = parser.add_subparsers(dest="import_mode", required=True)
    
    # option A: Sequence BLAST
    blast_parser = subparsers.add_parser("blast", help="Import sequences using the single sequence BLAST option", parents=[common_parser]).add_argument_group("Sequence BLAST Options")
    blast_parser.add_argument("--blast-query-file", required=True, type=str, help="The file containing a single sequence to use for the initial BLAST to obtain sequences")

    # option B: Family
    family_parser = subparsers.add_parser("family", help="Import sequences using the family option", parents=[common_parser]).add_argument_group('Family Options')
    family_parser.add_argument("--exclude-fragments", action="store_true", help="Do not import sequences marked as fragments by UniProt")
    family_parser.add_argument("--families", type=str, required=True, help="Comma-separated list of families to add")

    # option C: FASTA
    fasta_parser = subparsers.add_parser("fasta", help="Import sequences using the FASTA option", parents=[common_parser]).add_argument_group("FASTA Options")
    fasta_parser.add_argument("--fasta-file", required=True, type=str, help="The FASTA file to read sequences from")

    # option D: Accession IDs
    accession_parser = subparsers.add_parser("accessions", help="Import sequences using the Accession option", parents=[common_parser]).add_argument_group("Accession ID Options")
    accession_parser.add_argument("--accessions-file", required=True, type=str, help="The list of Accession IDs to pull sequences for, one per line")

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    """
    Test file path and rewrite them to be absolute. Ensures target directory
    exists and is empty. Modifies ``args`` parameter
    """
    fail = False
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

    if fail:
        print("Failed to render params template")
        exit(1)
    else:
        args.output_dir = os.path.abspath(args.output_dir)
        args.efi_config = os.path.abspath(args.efi_config)
        args.fasta_db = os.path.abspath(args.fasta_db)
        if os.path.exists(args.efi_db):
            args.efi_db = os.path.abspath(args.efi_db)
        return args

def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Render params.yml for EST nextflow pipeline", add_help=False)
    add_args(parser)
    return parser


def render_params(output_dir, duckdb_memory_limit, duckdb_threads, fasta_shards, accession_shards, blast_matches, job_id,
                  efi_config, fasta_db, efi_db, multiplex, blast_evalue,
                  import_mode, sequence_version,
                  families=None, exclude_fragments=None,
                  fasta_file=None,
                  accessions_file=None,
                  blast_query_file=None
                  ):
    params = {
        "final_output_dir": output_dir,
        "duckdb_memory_limit": duckdb_memory_limit,
        "duckdb_threads": duckdb_threads,
        "num_fasta_shards": fasta_shards,
        "num_accession_shards": accession_shards,
        "num_blast_matches": blast_matches,
        "multiplex": False,
        "job_id": job_id,
        "efi_config": efi_config,
        "fasta_db": fasta_db,
        "efi_db": efi_db,
        "import_mode": import_mode,
        "exclude_fragments": exclude_fragments,
        "multiplex": multiplex,
        "blast_evalue": blast_evalue,
        "sequence_version": sequence_version
    }
    if import_mode == "blast":
        params |= {
            "blast_query_file": blast_query_file
        }
    elif import_mode == "family":
        params |= {
            "families": families
        }
    elif import_mode == "fasta":
        params |= {
            "uploaded_fasta_file": fasta_file
        }
    elif import_mode == "accessions":
        params |= {
            "accessions_file": accessions_file
        }
    
    params_file = os.path.join(output_dir, "params.yml")
    with open(params_file, "w") as f:
        json.dump(params, f, indent=4)
    print(f"Wrote params to '{params_file}'")
    return params_file

if __name__ == "__main__":
    args = check_args(create_parser().parse_args())
    render_params(**vars(args))
