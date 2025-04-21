#!/usr/bin/env python3

import argparse
import copy
import os

import create_est_nextflow_params
import create_generatessn_nextflow_params
import create_colorssn_nextflow_params
import create_gnt_nextflow_params
import create_gnd_nextflow_params
import shared_args

def check_args(args: argparse.Namespace) -> argparse.Namespace:
    """
    Verify that the pipeline is valid and that the pipeline parameters are valid.  Will call
    ``exit(1)`` if the pipeline is invalid or if parameters are invalid
    """
    if args.pipeline == "colorssn":
        args = create_colorssn_nextflow_params.check_args(args)
    elif args.pipeline == "est":
        args = create_est_nextflow_params.check_args(args)
    elif args.pipeline == "generatessn":
        args = create_generatessn_nextflow_params.check_args(args)
    elif args.pipeline == "gnd":
        args = create_gnd_nextflow_params.check_args(args)
    elif args.pipeline == "gnt":
        args = create_gnt_nextflow_params.check_args(args)
    else:
        print(f"Job type '{args.pipeline}' not known")
        exit(1)

    return args

def create_parser() -> argparse.ArgumentParser:
    """
    Define the parent parser for job script creation and adds subcommands for
    different pipelines
    """
    parser = argparse.ArgumentParser(description="Create a job script from a template that runs Nextflow")
    subparsers = parser.add_subparsers(dest="pipeline", required=True)

    # add pipelines as subcommands
    colorssn_parser = subparsers.add_parser("colorssn", help="Create a Color SSN pipeline job script")
    create_colorssn_nextflow_params.add_args(colorssn_parser)

    est_parser = subparsers.add_parser("est", help="Create an EST pipeline job script")
    create_est_nextflow_params.add_args(est_parser)

    generatessn_parser = subparsers.add_parser("generatessn", help="Create a generate-SSN pipeline job script")
    create_generatessn_nextflow_params.add_args(generatessn_parser)

    gnd_parser = subparsers.add_parser("gnd", help="Create a GND pipeline job script")
    create_gnd_nextflow_params.add_args(gnd_parser)

    gnt_parser = subparsers.add_parser("gnt", help="Create a GNT pipeline job script")
    create_gnt_nextflow_params.add_args(gnt_parser)

    return parser

if __name__ == "__main__":
    args = check_args(create_parser().parse_args())

    # create params.yml file in the output directory
    if args.pipeline == "colorssn":
        params_file = create_colorssn_nextflow_params.render_params(**args)
        workflow_def = create_colorssn_nextflow_params.NXF_SCRIPT
    elif args.pipeline == "est":
        params_file = create_est_nextflow_params.render_params(**args)
        workflow_def = create_est_nextflow_params.NXF_SCRIPT
    elif args.pipeline == "generatessn":
        params_file = create_generatessn_nextflow_params.render_params(**args)
        workflow_def = create_generatessn_nextflow_params.NXF_SCRIPT
    elif args.pipeline == "gnt":
        params_file = create_gnt_nextflow_params.render_params(**args)
        workflow_def = create_gnt_nextflow_params.NXF_SCRIPT
    elif args.pipeline == "gnd":
        params_file = create_gnd_nextflow_params.render_params(**args)
        workflow_def = create_gnd_nextflow_params.NXF_SCRIPT

    shared_args.save_run_script(args, workflow_def=workflow_def, params_file=params_file)

