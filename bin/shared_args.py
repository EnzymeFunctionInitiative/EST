#!/usr/bin/env python3

import argparse
from jinja2 import Environment, FileSystemLoader, select_autoescape
import os

SCRIPT_NAME = "run_nextflow.sh"
PARAMS_NAME = "params.yml"
DEFAULT_TEMPLATE = "run_nextflow_cli.sh.jinja"

def add_args(parser: argparse.ArgumentParser, use_output_dir: bool = True):
    """
    Add arguments common to all pipeline parameters
    """
    if use_output_dir == True:
        parser.add_argument("--output-dir", required=True, type=str, help="Location for results. Will be created if it does not exist")
    parser.add_argument("--efi-config", required=True, type=str, help="EFI configuration file path")
    parser.add_argument("--efi-db", required=True, type=str, help="Name of the MySQL database to use (e.g. efi_202406) or name of the SQLite file")
    parser.add_argument("--nextflow-config", required=True, type=str, help="Path to the Nextflow configuration file to use (e.g. conf/est/docker.config)")
    parser.add_argument("--job-id", default=42, help="Identifier used to in the job name when submitting a Nextflow job to a scheduler")
    parser.add_argument("--workflow-def", help="Path to the Nextflow workflow definition file, relative to repository root (e.g. pipelines/est/est.nf)")

    # template args, for creating run scripts
    default_template_path = os.path.join(os.path.dirname(__file__), "templates")
    parser.add_argument("--templates-dir", type=str, default=default_template_path, help="Directory where job script templates are stored")
    # do not add a default value for --template because the create_nextflow_job.py script needs
    # to know if a template was specified or not
    parser.add_argument("--template", type=str, help="Name of template file to use -- must be one of those located in --templates-dir or bin/templates")

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    """
    Test file paths and rewrite them to be absolute. Ensures target directory
    exists and is empty. Modifies ``args`` parameter
    """
    fail = False

    if not os.path.exists(args.nextflow_config):
        print(f"Nextflow config file '{args.nextflow_config}' does not exist")
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

    # set the default template
    if args.template is None:
        args.template = DEFAULT_TEMPLATE

    if args.workflow_def is not None:
        args.workflow_def = os.path.abspath(args.workflow_def)

    if fail:
        return None
    else:
        args.output_dir = os.path.abspath(args.output_dir)
        args.efi_config = os.path.abspath(args.efi_config)
        args.nextflow_config = os.path.abspath(args.nextflow_config)
        if os.path.exists(args.efi_db):
            args.efi_db = os.path.abspath(args.efi_db)
        return args

def save_run_script(args: argparse.Namespace, workflow_def: str, params_file: str):
    """
    Save the nextflow execution command to a file for easier use by the user.

    Parameters
    ----------
        args
            ArgumentParser containing all the arguments used to generate the params file
        workflow_def
            Path to a Nextflow workflow definition
        params_file
            Path to a file containing the parameters passed to a Nextflow workflow
    """

    env = Environment(loader=FileSystemLoader(args.templates_dir), autoescape=select_autoescape())
    sh_template = env.get_template(args.template)

    pipeline_name = os.path.splitext(os.path.basename(workflow_def))

    run_script = sh_template.render(workflow_definition=workflow_def, 
                                    params_file=params_file,
                                    output_dir=args.output_dir,
                                    config_path=args.nextflow_config,
                                    jobtype=pipeline_name,
                                    job_id=args.job_id,
                                    report_file="report.html",
                                    timeline_file="timeline.html")
    startup_script = os.path.join(args.output_dir, SCRIPT_NAME)
    with open(startup_script, "w") as f:
        f.write(run_script)
        f.write("\n")
    print(f"Wrote Nextflow script to {startup_script}")

