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

2. *Add sequence length information*. Every `qseqid` and every `sseqid`
   represents a sequence from the input FASTA file. The lenghts of these
   sequences is needed for a later alignment score calculation. This stage
   computes sequence lengths and combines this information with the concatenated
   BLAST output.

3. *Compute Alignment Score*. The alignment score is computed for each BLAST
   entry and stored in the concatenated BLAST output file alongside other
   relevant values.

## Usage
1. Transcode the BLAST output and FASTA file into Parquet files. When both a
   BLAST output directory and FASTA file are passed, the SQL template will be
   generated.
   ```
   python transcode.py --blast-output <job-id>/output/blastout/ --fasta <job-id>/allsequences.fa
   ```
   This will produce `.parquet` versions of the BLAT output (in the same directory as the BLAST output) and a `.parquet` file containing seuqence IDs and sequence lengths.

2. Run the generated SQL file
   ```
   duckdb < reduce.sql
   ```
   This will produce a file `1.out.parquet` that contains the processed BLAST output.

## Technical details

A BLAST output file looks like this (column names added):
| qseqid     | sseqid     | pident | alignment_length | mismatches | gap_openings | qstart | qend | sstart | send | evalue | bitscore |
|------------|------------|--------|------------------|------------|--------------|--------|------|--------|------|--------|----------|
| A0A010NVS6 | A0A010NVS6 | 100.00 | 465              | 0          | 0            | 1      | 465  | 1      | 465  | 0.0    | 978      |
| A0A010NVS6 | A0A9D1VDT6 | 68.28  | 435              | 138        | 0            | 8      | 442  | 8      | 442  | 0.0    | 664      |
| A0A010NVS6 | A0A644ZDI5 | 67.27  | 440              | 144        | 0            | 1      | 440  | 1      | 440  | 0.0    | 658      |
| A0A010NVS6 | A0A9D1TFA1 | 65.32  | 444              | 154        | 0            | 8      | 451  | 10     | 453  | 0.0    | 650      |
| A0A010NVS6 | A0A354I928 | 64.79  | 443              | 156        | 0            | 8      | 450  | 8      | 450  | 0.0    | 649      |

EFI only uses a subset of the columns. Self-matches and duplicates are filtered out:
| qseqid     | sseqid     | pident | alignment_length | bitscore |
|------------|------------|--------|------------------|----------|
| A0A010NVS6 | A0A9D1VDT6 | 68.28  | 435              | 664      |
| A0A010NVS6 | A0A644ZDI5 | 67.27  | 440              | 658      |
| A0A010NVS6 | A0A9D1TFA1 | 65.32  | 444              | 650      |
| A0A010NVS6 | A0A354I928 | 64.79  | 443              | 649      |

Then two additional columns are using the associated FASTA file:
| qseqid     | sseqid     | pident | alignment_length | bitscore | query_length | subject_length|
|------------|------------|--------|------------------|----------|--------------|---------------|
| A0A010NVS6 | A0A9D1VDT6 | 68.28  | 435              | 664      | 3672         | 2536          |
| A0A010NVS6 | A0A644ZDI5 | 67.27  | 440              | 658      |  263         | 1836          |
| A0A010NVS6 | A0A9D1TFA1 | 65.32  | 444              | 650      | 1938         | 927           |
| A0A010NVS6 | A0A354I928 | 64.79  | 443              | 649      | 1211         | 134           |

To make this process fast, the computational steps are as follows:
1. *Transcode BLAST output to Parquet*. Each BLAST output shard is transcoded to
   a Parquet file. Unused columns are dropped during the conversion.

2. *Count sequence lengths and store in Parquet*. The input FASTA file is
   iterated through and sequence identifiers are stored alongside their
   respective lengths in a Parquet file.

3. *Render a SQL file*. A template SQL file is processed to produce a sequence
   of SQL commands. This uses Python's `string.Template` standard library
   module.

4. *Execute SQL on BLAST output and FASTA sequence lengths*. The rendered SQL
   file is used to deduplicate BLAST output and pair each line with its sequence
   counts. DuckDB saves the output in a Parquet file.