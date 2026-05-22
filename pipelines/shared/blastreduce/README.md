# EFI BLAST-reduce

In this stage, BLAST output shards are collected into a single file. 

The previous stage splits the input FASTA file into shards (typically 64) and
distributes the search over the cluster for better performance. Each individual
search produces its own tabular output file. These files represent the complete
output of the all-by-all BLAST.

This stage performs the following operations:

1. *Deduplicate BLAST output*. Because an all-by-all BLAST is run, there may be
   multiple copies of pairs of sequence identifiers present in the output. Only
   one of these pairs is desired, so this stage removes all but the first
   occurence (smallest when sorted lexicographically by `qseqid` and `sseqid`).
   The deduplication is run on each individual shard for performance reasons.

2. *Add sequence length information*. Every `qseqid` and every `sseqid`
   represents a sequence from the input FASTA file. The lengths of these
   sequences is needed for a later alignment score calculation. This stage
   computes sequence lengths and combines this information with the concatenated
   BLAST output.

3. *Compute Alignment Score*. The individually-processed shards are merged and
   the alignment score is computed for each BLAST entry and stored in the
   concatenated BLAST output file alongside other relevant values.

4. *Final deduplication*. In order to account for edge cases, a final
   deduplication is run on the merged dataset and the output is sorted.

## Usage

1. Transcode the BLAST output and FASTA file into Parquet files. When both a
   BLAST output directory and FASTA file are passed, the SQL template will be
   generated.

   ```
   python transcode_fasta_lengths.py --fasta all_sequences.fasta --output all_sequences.fasta.parquet
   ```

   This will produce a `.parquet` version of the FASTA file containing all of
   the sequences, and is used for sequence lengths in a later step.

2. The all-by-all BLAST is run and parquet files are generated.

3. Perform sorting and reduction on the BLAST parquet files output from the
   all-by-all workflow.

   ```
    python map_blast_reduce.py \
        --blast-output  \
        --fasta-length-parquet all_sequences.fasta.parquet \
        --duckdb-memory-limit 6GB \
        --duckdb-temp-dir duckdb-temp \
        --output-file 1.out.parquet
   ```

   This will produce a file `1.out.parquet` that contains the processed BLAST
   output including alignment score, etc.

## Technical details

A BLAST output file looks like this (column names added):

| qseqid     | sseqid     | pident | alignment_length | mismatches | gap_openings | qstart | qend | sstart | send | evalue | bitscore |
|------------|------------|--------|------------------|------------|--------------|--------|------|--------|------|--------|----------|
| A0A010NVS6 | A0A010NVS6 | 100.00 | 465              | 0          | 0            | 1      | 465  | 1      | 465  | 0.0    | 978      |
| A0A010NVS6 | A0A9D1VDT6 | 68.28  | 435              | 138        | 0            | 8      | 442  | 8      | 442  | 0.0    | 664      |
| A0A010NVS6 | A0A9D1VDT6 | 68.28  | 435              | 138        | 0            | 8      | 442  | 8      | 442  | 0.0    | 664      |
| A0A010NVS6 | A0A644ZDI5 | 67.27  | 440              | 144        | 0            | 1      | 440  | 1      | 440  | 0.0    | 658      |
| A0A010NVS6 | A0A9D1TFA1 | 65.32  | 444              | 154        | 0            | 8      | 451  | 10     | 453  | 0.0    | 650      |
| A0A010NVS6 | A0A354I928 | 64.79  | 443              | 156        | 0            | 8      | 450  | 8      | 450  | 0.0    | 649      |

EFI only uses a subset of the columns. Duplicates are filtered out:

| qseqid     | sseqid     | pident | alignment_length | bitscore |
|------------|------------|--------|------------------|----------|
| A0A010NVS6 | A0A010NVS6 | 100.00 | 465              | 978      |
| A0A010NVS6 | A0A9D1VDT6 | 68.28  | 435              | 664      |
| A0A010NVS6 | A0A644ZDI5 | 67.27  | 440              | 658      |
| A0A010NVS6 | A0A9D1TFA1 | 65.32  | 444              | 650      |
| A0A010NVS6 | A0A354I928 | 64.79  | 443              | 649      |

Then two additional columns are using the associated FASTA file:

| qseqid     | sseqid     | pident | alignment_length | bitscore | query_length | subject_length |
|------------|------------|--------|------------------|----------|--------------|----------------|
| A0A010NVS6 | A0A010NVS6 | 100.00 | 465              | 978      | 465          | 465            |
| A0A010NVS6 | A0A9D1VDT6 | 68.28  | 435              | 664      | 465          | 454            |
| A0A010NVS6 | A0A644ZDI5 | 67.27  | 440              | 658      | 465          | 451            |
| A0A010NVS6 | A0A9D1TFA1 | 65.32  | 444              | 650      | 465          | 453            |
| A0A010NVS6 | A0A354I928 | 64.79  | 443              | 649      | 465          | 450            |

To make this process efficient, each BLAST output shard file is processed
individually to remove duplicates, as well as add query and subject lengths
and compute alignment score.  Then all files are merged together into one
file and a final deduplication and sort occurs before a single merged
`1.out.parquet` file is written

