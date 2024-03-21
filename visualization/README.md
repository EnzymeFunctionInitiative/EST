# EFI Visualization
This code replaces several perl + R scripts previously used to generate plots. Source code is in `src`. This is not a python package.

`process_blast_results.py` takes a BLAST output file as input will render:
- A boxplot of alignment score vs count
- A boxplot of percent identical vs count
- A histogram of alignment score vs edge count
- A tabular file of alignment score values

It uses a pandas dataframe to do calculations. This makes it fast, but also very memory-hungry.

`plot_length_data.py` renders a histogram from a uniprot or uniref length file.

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
   python3 process_blast_results.py --blast-output 1.out --job-id 131
   ```

4. Generate the uniref/uniprot length histogram
   ```
   python3 plot_length_data.py --evalue-table length_uniprot.tab