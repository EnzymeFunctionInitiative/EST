import argparse
from jinja2 import Environment, FileSystemLoader, select_autoescape
import os
import sys

def parse_args():
    parser = argparse.ArgumentParser(description="Render templates for nextflow job run")
    parser.add_argument("--workflow-def", type=str, default="est.nf", help="Location of the nextflow workflow file")
    parser.add_argument("--est-dir", type=str, default=".", help="Directory where EST scripts are")
    parser.add_argument("--job-id", type=int, required=True, help="Job ID number to rerun using nextflow")
    parser.add_argument("--output-dir", type=str, required=True, help="Where to store outputs from run")
    parser.add_argument("--duckdb-threads", type=int, default=1, help="Number of threads to let DuckDB use")
    parser.add_argument("--duckdb-mem", type=str, default="4GB", help="Soft limit on RAM for DuckDB")
    parser.add_argument("--fasta-shards", type=int, default=64, help="Number of pieces to break the FASTA file into")
    parser.add_argument("--blast-matches", type=int, default=250, help="Number of matches for BLAST to return for each query")
    parser.add_argument("--config-path", type=str, required=True, help="Path to nextflow config file for run")
    args = parser.parse_args()

    fail = False
    if not os.path.exists(args.est_dir):
        print(f"est dir '{args.est_dir}' does not exist", file=sys.stderr)
        fail = True
    if not os.path.exists(args.workflow_def):
        print(f"workflow definition '{args.workflow_def}' does not exist", file=sys.stderr)
        fail = True
    if not os.path.exists(args.config_path):
        print(f"config path '{args.config_path}' does not exist", file=sys.stderr)
        fail = True
    
    if fail:
        exit(1)
    else:
        return args


if __name__ == "__main__":
    args = parse_args()
    args.output_dir = os.path.join(args.output_dir, f"rerun_{args.job_id}")
    os.makedirs(args.output_dir, exist_ok=True)

    env = Environment(loader=FileSystemLoader(f"{args.est_dir}/templates"), autoescape=select_autoescape())
    params_template = env.get_template("params.yml.jinja")
    sh_template = env.get_template("run_nextflow_slurm.sh.jinja")

    params = params_template.render(est_dir=args.est_dir, 
                                    job_dir=f"/private_stores/gerlt/jobs/dev/est/{args.job_id}", 
                                    output_dir=args.output_dir,
                                    duckdb_threads=args.duckdb_threads,
                                    duckdb_mem=args.duckdb_mem,
                                    fasta_shards=args.fasta_shards,
                                    blast_matches=args.blast_matches,
                                    job_id=args.job_id)
    params_output = os.path.join(args.output_dir, "params.yml")
    with open(params_output, "w") as f:
        f.write(params)
    print(f"Wrote params to {params_output}")

    submission_script = sh_template.render(workflow_definition=args.workflow_def, 
                                           params_file=params_output,
                                           report_file="report.html",
                                           timeline_file="timeline.html",
                                           output_dir=args.output_dir,
                                           job_id=args.job_id,
                                           config_path=args.config_path)
    submission_script_output = os.path.join(args.output_dir, "run_nextflow.sh")
    with open(submission_script_output, "w") as f:
        f.write(submission_script)
    print(f"Wrote submission script to {submission_script_output}")