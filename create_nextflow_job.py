import argparse
from jinja2 import Environment, FileSystemLoader, select_autoescape
import os

def parse_args():
    parser = argparse.ArgumentParser(description="Render templates for nextflow job run")
    parser.add_argument("--job-id", type=int, default=29897, help="Job ID number to rerun using nextflow")
    parser.add_argument("--output-dir", type=str, required=True, help="Where to store outputs from run")
    parser.add_argument("--template-dir", type=str, required=True, help="Where the templates are stored")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    args.output_dir = os.path.join(args.output_dir, f"rerun_{args.job_id}")
    os.makedirs(args.output_dir, exist_ok=True)

    env = Environment(loader=FileSystemLoader(args.template_dir), autoescape=select_autoescape())
    params_template = env.get_template("params.yml.jinja")
    sh_template = env.get_template("run_nextflow.sh.jinja")

    params = params_template.render(est_dir="/home/a-m/demeyer3/EST", job_dir=f"/private_stores/gerlt/jobs/dev/est/{args.job_id}", output_dir=args.output_dir)
    params_output = os.path.join(args.output_dir, "params.yml")
    with open(params_output, "w") as f:
        f.write(params)
    
    submission_script = sh_template.render(workflow_definition="/home/a-m/demeyer3/EST/endstages.nf", params_file=params_output, report_file="report.html", timeline_file="timeline.html",output_dir=args.output_dir,job_id=args.job_id)
    with open(os.path.join(args.output_dir, "run_nextflow.sh"), "w") as f:
        f.write(submission_script)