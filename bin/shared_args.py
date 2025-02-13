#!/usr/bin/env python3

import argparse
import os

SCRIPT_NAME = "run_nextflow.sh"
PARAMS_NAME = "params.yml"

def add_args(parser: argparse.ArgumentParser):
    """
    Add arguments common to all pipeline parameters
    """
    parser.add_argument("--output-dir", required=True, type=str, help="Location for results. Will be created if it does not exist")
    parser.add_argument("--efi-config", required=True, type=str, help="EFI configuration file path")
    parser.add_argument("--efi-db", required=True, type=str, help="Name of the MySQL database to use (e.g. efi_202406) or name of the SQLite file")
    parser.add_argument("--nextflow-config", required=True, type=str, help="Path to the Nextflow configuration file to use (e.g. conf/est/docker.config)")
    parser.add_argument("--job-id", default=131, help="ID used when running on the EFI website. Not important otherwise")

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

    if fail:
        print("Failed to render params template")
        return None
    else:
        args.output_dir = os.path.abspath(args.output_dir)
        args.efi_config = os.path.abspath(args.efi_config)
        args.nextflow_config = os.path.abspath(args.nextflow_config)
        if os.path.exists(args.efi_db):
            args.efi_db = os.path.abspath(args.efi_db)
        return args

def create_parser():
    return parser

def save_run_script(args: argparse.ArgumentParser, nxf_script_path: str):
    """
    Save the nextflow execution command to a file for easier use by the user.

    Parameters
    ----------
        args
            ArgumentParser containing all the arguments used to generate the params file
        nxf_script_path
            path to the nextflow script relative to the repo root (e.g. 'pipelines/est/est.nf')
    """
    script = os.path.join(args.output_dir, SCRIPT_NAME)
    efi_data_dir = os.path.dirname(args.efi_config)
    nxf_log_file = os.path.join(args.output_dir, "nextflow.log")
    nxf_work_dir = os.path.join(args.output_dir, "work")
    params_file = os.path.join(args.output_dir, PARAMS_NAME)
    nxf_script_path = os.path.join(os.path.dirname(__file__), "../", nxf_script_path)

    with open(script, "w") as fh:
        fh.write("#!/bin/bash\n")
        fh.write(f"export EFI_DATA_DIR=\"{efi_data_dir}\"\n")
        fh.write(f"nextflow -C {args.nextflow_config} -log {nxf_log_file} run {nxf_script_path} -params-file {params_file} -w {nxf_work_dir}\n")
        #nextflow -log $OUTPUT_DIR/est_nextflow.log -C $NXF_EST_CONFIG_FILE run pipelines/est/est.nf -params-file $OUTPUT_DIR/params.yml -w $OUTPUT_DIR/est_work

