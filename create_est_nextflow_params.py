import argparse
import json
import os

def add_args(parser: argparse.ArgumentParser):
    parser.add_argument("--output-dir", required=True, type=str, help="Location for results. Will be created if it does not exist")
    parser.add_argument("--duckdb-memory-limit", default="8GB", type=str, help="Soft limit on DuckDB memory usage")
    parser.add_argument("--duckdb-threads", default=1, type=int, help="Number of threads DuckDB can use. More threads means higher memory usage")
    parser.add_argument("--fasta-shards", default=128, type=int, help="Number of files to split FASTA into. File is split so that BLAST can be parallelized")
    parser.add_argument("--accession-shards", default=16, type=int, help="Number of files to split Accessions list into. File is split so that sequence retrieval can be parallelized")
    parser.add_argument("--blast-matches", default=250, type=int, help="Number of matches BLAST should return")
    parser.add_argument("--job-id", default=131, help="ID used when running on the EFI website. Not important otherwise")
    parser.add_argument("--efi-config", required=True, type=str, help="EFI configuration file path")
    parser.add_argument("--fasta-db", type=str, required=True, help="FASTA file or BLAST database to retrieve sequences from")
    parser.add_argument("--efi-db", required=True, type=str, help="Name of the MySQL database to use (e.g. efi_202406)")
    parser.add_argument("--import-mode", required=True, choices=["BLAST", "family", "FASTA", "accession"], help="How to import sequences")
    parser.add_argument("--exclude-fragments", action="store_true", help="Do not import sequences marked as fragments by UniProt")
    parser.add_argument("--families", type=str, help="Comma-separated list of families to add")
    parser.add_argument("--family-id-format", choices=["UniProt", "UniRef90", "UniRef50"])
    parser.add_argument("--multiplex", action="store_true", help="Use CD-HIT to reduce the number of sequences used in analysis")

def check_args(args: argparse.Namespace) -> argparse.Namespace:
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
    
    if not os.path.exists(args.fasta_db):
        print(f"FASTA database '{args.fasta_db}' does not exist")
        fail = True

    if fail:
        print("Failed to render params template")
        exit(1)
    else:
        args.output_dir = os.path.abspath(args.output_dir)
        args.efi_config = os.path.abspath(args.efi_config)
        args.fasta_db = os.path.abspath(args.fasta_db)
        return args

def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Render params.yml for EST nextflow pipeline")
    add_args(parser)
    return parser


def render_params(output_dir, duckdb_memory_limit, duckdb_threads, fasta_shards, accession_shards, blast_matches, job_id, efi_config, fasta_db, efi_db, import_mode, exclude_fragments, families, family_id_format, multiplex):
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
        "multiplex": multiplex
    }
    if import_mode == "family":
        fail = False
        if families is None:
            print("Specified 'family' as import method but did not supply any families with --families option")
            fail = True
        if family_id_format is None:
            print("Specified 'family' as import method but did not supply the family id format with --family-id-format")
            fail = True
        if fail:
            exit(1)
        params |= {
            "families": families,
            "family_id_format": family_id_format
        }
    
    params_file = os.path.join(output_dir, "params.yml")
    with open(params_file, "w") as f:
        json.dump(params, f, indent=4)
    print(f"Wrote params to '{params_file}'")
    return params_file

if __name__ == "__main__":
    args = check_args(create_parser().parse_args)
    render_params(**vars(args))
