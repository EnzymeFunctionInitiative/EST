import argparse
import os
import string

def add_parameter_args(parser: argparse.ArgumentParser):
    parser.add_argument("--fasta-file", required=True, type=str, help="FASTA file to create SSN from")
    parser.add_argument("--output-dir", required=True, type=str, help="Location for results. Will be created if it does not exist")
    parser.add_argument("--template-file", default="templates/params-template.yml", help="The location of the params template file")
    parser.add_argument("--duckdb-memory-limit", default="8GB", type=str, help="Soft limit on DuckDB memory usage")
    parser.add_argument("--duckdb-threads", default=1, type=int, help="Number of threads DuckDB can use. More threads means higher memory usage")
    parser.add_argument("--fasta-shards", default=128, type=int, help="Number of files to split FASTA input into. File is split so that BLAST can be parallelized")
    parser.add_argument("--blast-matches", default=250, type=int, help="Number of matches BLAST should return")
    parser.add_argument("--job-id", default=131, help="ID used when running on the EFI website. Not important otherwise")
    parser.add_argument("--import-mode", choices=["BLAST", "family", "FASTA", "accession"], help="How to import sequences")
    parser.add_argument("--exclude-fragments", action="store_true", help="Do not import sequences marked as fragments by UniProt")
    parser.add_argument("--families", type=string, help="Comma-separated list of families to add")
    parser.add_argument("--family-id-format", choices=["UniProt", "UniRef90", "UniRef50"])

def parse_args():
    parser = argparse.ArgumentParser(description="Render params-template.yml for EST nextflow pipeline")
    add_parameter_args(parser)

    args = parser.parse_args()

    fail = False
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

    if fail:
        print("Failed to render params template")
        exit(1)
    else:
        args.fasta_file = os.path.abspath(args.fasta_file)
        args.output_dir = os.path.abspath(args.output_dir)
        return args

def render_params_template(fasta_file, output_dir, template_file, duckdb_memory_limit, duckdb_threads, fasta_shards, blast_matches, job_id, import_mode, exclude_fragments, families, family_id_format):
    mapping = {
        "fasta_file": fasta_file,
        "output_dir": output_dir,
        "duckdb_mem": duckdb_memory_limit,
        "duckdb_threads": duckdb_threads,
        "fasta_shards": fasta_shards,
        "blast_matches": blast_matches,
        "job_id": job_id,
        "efi_config": "",
        "fasta_db": "",
        "import_mode": import_mode,
        "exclude_fragments": exclude_fragments,
        "families": families,
        "family_id_format": family_id_format

    }
    with open(template_file) as f:
        template = string.Template(f.read())
    output_file = os.path.join(output_dir, "params.yml")
    with open(output_file, "w") as params_file:
        params_file.write(template.substitute(mapping))
    print(f"Wrote params to '{output_file}'")
    return output_file

if __name__ == "__main__":
    args = parse_args()
    render_params_template(**vars(args))
