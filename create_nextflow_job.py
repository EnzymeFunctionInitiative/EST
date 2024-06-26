import argparse
import copy
from jinja2 import Environment, FileSystemLoader, select_autoescape
import os

import create_est_nextflow_params
import create_ssn_nextflow_params

def check_args(args: argparse.Namespace) -> tuple[str, argparse.Namespace]:
    if not os.path.exists(args.workflow_def):
        print(f"Workflow definition '{args.workflow_def}' does not exist")
        print("Failed to generate run script")
        exit(1)
    else:
        args.workflow_def = os.path.abspath(args.workflow_def)

    if vars(args).get("ssn_name") is None:
        # check EST args
        args = create_est_nextflow_params.check_args(args)
        return "est", args
    else:
        # ssn_name is required by the SSN param generator parser, if it is
        # present then we know we are creating an SSN param file/job script
        args = create_ssn_nextflow_params.check_args(args)
        return "ssn", args

def create_parser():
    parser = argparse.ArgumentParser(description="Render templates for nextflow job run")
    # batch args
    parser.add_argument("--templates-dir", type=str, default="./templates", help="Directory where EST templates are stored")
    parser.add_argument("--config-path", type=str, default="conf/slurm.conf", help="Path to nextflow config file for run")
    subparsers = parser.add_subparsers()

    est_parser = subparsers.add_parser("est", help="Create an EST pipeline job script")
    est_parser.add_argument("--workflow-def", type=str, default="est.nf", help="Location of the EST nextflow workflow file")
    create_est_nextflow_params.add_args(est_parser)

    ssn_parser = subparsers.add_parser("ssn", help="Create an SSN pipeline job script")
    ssn_parser.add_argument("--workflow-def", type=str, default="ssn.nf", help="Location of the SSN nextflow workflow file")
    create_ssn_nextflow_params.add_args(ssn_parser)

    return parser


if __name__ == "__main__":
    jobtype, args = check_args(create_parser().parse_args())

    # remove args not relevant to params rendering
    args_dict = copy.deepcopy(vars(args))
    del args_dict["workflow_def"]
    del args_dict["templates_dir"]
    del args_dict["config_path"]
    if jobtype == "est":
        params_output = create_est_nextflow_params.render_params(**args_dict)
    elif jobtype == "ssn":
        params_output = create_ssn_nextflow_params.render_params(**args_dict)
    else:
        print(f"Job type '{jobtype}' not known")
        exit(1)


    env = Environment(loader=FileSystemLoader(args.templates_dir), autoescape=select_autoescape())
    sh_template = env.get_template("run_nextflow_slurm.sh.jinja")

    submission_script = sh_template.render(workflow_definition=args.workflow_def, 
                                           params_file=params_output,
                                           report_file="report.html",
                                           timeline_file="timeline.html",
                                           output_dir=args.output_dir,
                                           jobtype=jobtype,
                                           job_id=args.job_id,
                                           config_path=args.config_path,
                                           load_modules=True)
    submission_script_output = os.path.join(args.output_dir, "run_nextflow.sh")
    with open(submission_script_output, "w") as f:
        f.write(submission_script)
        f.write("\n")
    print(f"Wrote submission script to {submission_script_output}")