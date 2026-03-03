
import argparse
import json
from BioHMMLogo import BioHMMLogo

def convert_hmm_to_skylign_json(hmm_path, output_json_path, output_png_path):
    logo = BioHMMLogo(hmm_path)
    logo_json = logo.as_json()
    with open(output_json_path, "w") as fh:
        fh.write(logo_json)
    logo_png = logo.as_png()
    logo_png.save(output_png_path)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert HMM output from HMMER into a JSON structure that can be used by Skylign for visualization")
    parser.add_argument("--hmm", required=True, type=str, help="Path to the input HMM file")
    parser.add_argument("--json", required=True, type=str, help="Path to the output JSON file")
    parser.add_argument("--png", required=True, type=str, help="Path to the output PNG file")
    args = parser.parse_args()
    convert_hmm_to_skylign_json(args.hmm, args.json, args.png)
