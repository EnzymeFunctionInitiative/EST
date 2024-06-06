import argparse
import copy
from jinja2 import Environment, FileSystemLoader, select_autoescape
import os
import sys

from create_est_nextflow_params import render_params_template

def parse_args():
    parser = argparse.ArgumentParser(description="Render templates for nextflow job run")
    # batch args
    parser.add_argument("--workflow-def", type=str, default="est.nf", help="Location of the nextflow workflow file")
    parser.add_argument("--templates-dir", type=str, default="./templates", help="Directory where EST templates are stored")
    parser.add_argument("--config-path", type=str, required=True, help="Path to nextflow config file for run")
    
    # params args
    parser.add_argument("--fasta-file", required=True, type=str, help="FASTA file to create SSN from")
    parser.add_argument("--output-dir", required=True, type=str, help="Location for results. Will be created if it does not exist")
    parser.add_argument("--duckdb-memory-limit", default="8GB", type=str, help="Soft limit on DuckDB memory usage")
    parser.add_argument("--duckdb-threads", default=1, type=int, help="Number of threads DuckDB can use. More threads means higher memory usage")
    parser.add_argument("--fasta-shards", default=128, type=int, help="Number of files to split FASTA input into. File is split so that BLAST can be parallelized")
    parser.add_argument("--blast-matches", default=250, type=int, help="Number of matches BLAST should return")
    parser.add_argument("--job-id", default=131, help="ID used when running on the EFI website. Not important otherwise")
    args = parser.parse_args()

    fail = False
    if not os.path.exists(args.templates_dir):
        print(f"templates dir '{args.templates_dir}' does not exist", file=sys.stderr)
        fail = True
    if not os.path.exists(args.workflow_def):
        print(f"workflow definition '{args.workflow_def}' does not exist", file=sys.stderr)
        fail = True
    if not os.path.exists(args.config_path):
        print(f"config path '{args.config_path}' does not exist", file=sys.stderr)
        fail = True
    if not os.path.exists(args.fasta_file):
        print(f"FASTA file '{args.fasta_file}' does not exist")
        fail = True
    if os.path.exists(args.output_dir):
        if len(os.listdir(args.output_dir)) > 0:
            print(f"Output directory '{args.output_dir}' is not empty, refusing to render templates")
            fail = True
    else:
        try:
            os.makedirs(args.output_dir)
        except Exception as e:
            print(f"Could not create output directory '{args.output_dir}': {e}")
            fail = True
    
    if fail:
        print("Failed to render templates")
        exit(1)
    else:
        args.workflow_def = os.path.abspath(args.workflow_def)
        args.templates_dir = os.path.abspath(args.templates_dir)
        args.config_path = os.path.abspath(args.config_path)
        args.fasta_file = os.path.abspath(args.fasta_file)
        args.output_dir = os.path.abspath(args.output_dir)
        return args


if __name__ == "__main__":
    args = parse_args()

    # remove args not relevant to params rendering
    args_dict = copy.deepcopy(vars(args))
    del args_dict["workflow_def"]
    del args_dict["templates_dir"]
    del args_dict["config_path"]
    args_dict["template_file"] = os.path.join(args.templates_dir, "params-template.yml")
    params_output = render_params_template(**args_dict)

    env = Environment(loader=FileSystemLoader(args.templates_dir), autoescape=select_autoescape())
    sh_template = env.get_template("run_nextflow_slurm.sh.jinja")

    submission_script = sh_template.render(workflow_definition=args.workflow_def, 
                                           params_file=params_output,
                                           report_file="report.html",
                                           timeline_file="timeline.html",
                                           output_dir=args.output_dir,
                                           job_id=args.job_id,
                                           config_path=args.config_path,
                                           load_modules=True)
    submission_script_output = os.path.join(args.output_dir, "run_nextflow.sh")
    with open(submission_script_output, "w") as f:
        f.write(submission_script)
        f.write("\n")
    print(f"Wrote submission script to {submission_script_output}")