# EFI Visualization
This code replaces several perl + R scripts previously used to generate plots. Source code is in `src`. This is not a python package.

`process_blast_results.py` takes a BLAST output file as input will render:
- A boxplot of alignment score vs alignment length
- A boxplot of alignment score vs percent id
- A histogram of alignment score vs edge count
- A tabular file of sorted alignment score values with a cumulative sum

`plot_length_data.py` renders a length histogram from a FASTA file

## Usage
This code was develop with Python 3.10.12. Python 3.10.x should be used to run it.

1. Create a python environment using python 3.10.x
   ```
   python3 -mvenv efi-viz
   ```

2. Activate the environment and install required packages
   ```
   source efi-viz/bin/activate; pip install -R requirements.txt
   ```

3. Generate BLAST visualizations
   ```
   python3 process_blast_results.py --blast-output 1.out --job-id 131 --length-plot-filename length --pidentplot-filename pident --edgehist-filename edge --output-type png --evalue-tab-filename evalue.tab
   ```

4. Generate the uniref/uniprot length histogram
   ```
   python3 plot_length_data.py --evalue-table length_uniprot.tab --job-id 131
   ```
