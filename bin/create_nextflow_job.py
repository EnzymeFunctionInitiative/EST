#!/usr/bin/env python
import argparse
import copy
from jinja2 import Environment, FileSystemLoader, select_autoescape
import os

import create_est_nextflow_params
import create_generatessn_nextflow_params
import create_colorssn_nextflow_params

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    """
    Verify that paths exist and destinations directories exist/are empty. Make
    paths absolute. Will call ``exit(1)`` if files do not exist.
    """
    fail = False
    if not os.path.exists(args.workflow_def):
        print(f"Workflow definition '{args.workflow_def}' does not exist")
        fail = True

    if not os.path.exists(args.config_path):
        print(f"Nextflow configuration file '{args.config_path}' does not exist")
        fail = True

    if fail:
        print("Failed to generate run script")
        exit(1)
    else:
        args.workflow_def = os.path.abspath(args.workflow_def)
        args.config_path = os.path.abspath(args.config_path)

    if args.command == "colorssn":
        args = create_colorssn_nextflow_params.check_args(args)
    elif args.command == "est":
        args = create_est_nextflow_params.check_args(args)
    elif args.command == "ssn":
        args = create_generatessn_nextflow_params.check_args(args)
    else:
        print(f"Job type '{args.command}' not known")
        exit(1)

    return args

def create_parser() -> argparse.ArgumentParser:
    """
    Define the parent parser for job script creation and adds subcommands for
    different pipelines
    """
    parser = argparse.ArgumentParser(description="Render templates for nextflow job run")
    # batch args
    default_template_path = os.path.join(os.path.dirname(__file__), "templates")
    parser.add_argument("--templates-dir", type=str, default=default_template_path, help="Directory where job script templates are stored")
    parser.add_argument("--config-path", type=str, required=True, help="Path to nextflow config file for pipeline")
    subparsers = parser.add_subparsers(dest="pipeline", required=True,)

    # add pipelines as subcommands
    colorssn_parser = subparsers.add_parser("colorssn", help="Create a Color SSN pipeline job script")
    nxf_script_path = os.path.join(os.path.dirname(__file__), "../pipelines/colorssn/colorssn.nf")
    colorssn_parser.add_argument("--workflow-def", default=nxf_script_path, help="Location of the Color SSN nextflow workflow file")
    create_colorssn_nextflow_params.add_args(colorssn_parser)

    est_parser = subparsers.add_parser("est", help="Create an EST pipeline job script")
    nxf_script_path = os.path.join(os.path.dirname(__file__), "../pipelines/est/est.nf")
    est_parser.add_argument("--workflow-def", type=str, default=nxf_script_path, help="Location of the EST nextflow workflow file")
    create_est_nextflow_params.add_args(est_parser)

    generatessn_parser = subparsers.add_parser("generatessn", help="Create a generate-SSN pipeline job script")
    nxf_script_path = os.path.join(os.path.dirname(__file__), "../pipelines/generatessn/generatessn.nf")
    generatessn_parser.add_argument("--workflow-def", type=str, default=nxf_script_path, help="Location of the SSN nextflow workflow file")
    create_generatessn_nextflow_params.add_args(generatessn_parser)

    return parser


if __name__ == "__main__":
    args = check_args(create_parser().parse_args())

    # remove args not relevant to params rendering
    args_dict = copy.deepcopy(vars(args))
    del args_dict["command"]
    del args_dict["workflow_def"]
    del args_dict["templates_dir"]
    del args_dict["config_path"]
    if args.command == "colorssn":
        params_output = create_colorssn_nextflow_params.render_params(**args_dict)
    elif args.command == "est":
        params_output = create_est_nextflow_params.render_params(**args_dict)
    elif args.command == "ssn":
        params_output = create_generatessn_nextflow_params.render_params(**args_dict)
    else:
        print(f"Job type '{args.command}' not known")
        exit(1)


    env = Environment(loader=FileSystemLoader(args.templates_dir), autoescape=select_autoescape())
    sh_template = env.get_template("run_nextflow_slurm.sh.jinja")

    submission_script = sh_template.render(workflow_definition=args.workflow_def, 
                                           params_file=params_output,
                                           report_file="report.html",
                                           timeline_file="timeline.html",
                                           output_dir=args.output_dir,
                                           jobtype=args.command,
                                           job_id=args.job_id,
                                           config_path=args.config_path,
                                           load_modules=True)
    submission_script_output = os.path.join(args.output_dir, "run_nextflow.sh")
    with open(submission_script_output, "w") as f:
        f.write(submission_script)
        f.write("\n")
    print(f"Wrote submission script to {submission_script_output}")