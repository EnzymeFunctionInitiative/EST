process import_sequences {
    input:
        val existing_fasta_file
    output:
        path "sequences.fa"
    """
    cp $existing_fasta_file sequences.fa
    """
}

process create_blast_db {
    input:
        path fasta_file
    output:
        path "database.*"
        val "database"
    """
    module load efidb/ip98
    module load efiest/devlocal
    formatdb -i ${fasta_file} -n database -p T -o T
    """
}

process split_fasta {
    input:
        path fasta_file
    output:
        path "fracfile-*.fa"
    """
    ${params.est_dir}/split_fasta.pl -parts ${params.num_fasta_shards} -source ${fasta_file}
    """
}

process all_by_all_blast {
    input:
        path(blast_db_files, arity: 5)
        val blast_db_name
        each path(frac)
    output:
        path "${frac}.tab.parquet"
    """
    export PATH="/private_stores/gerlt/test_lib:$PATH"
    module load efidb/ip98
    module load efiest/devlocal
    module load Python
    module load efiest/python_est_1.0
    blastall -p blastp -i $frac -d $blast_db_name -m 8 -e 1e-5 -b 250 -o ${frac}.tab
    python ${params.est_dir}/blastreduce/transcode_blast.py --blast-output ${frac}.tab
    """
}

process blastreduce_transcode_fasta {
    input:
        path fasta_file
    output:
        path "${fasta_file.getName()}.parquet"

    """
    module load Python
    module load efiest/python_est_1.0
    python ${params.est_dir}/blastreduce/transcode_fasta_lengths.py --fasta $fasta_file --output ${fasta_file.getName()}.parquet
    """
}

process blastreduce {
    publishDir "$baseDir/nextflow_results/", mode: 'copy'
    input:
        path blast_files
        path fasta_length_parquet

    output:
        path "1.out.parquet"

    """
    module load Python
    module load efiest/python_est_1.0
    python ${params.est_dir}/blastreduce/render_sql_template.py --blast-output $blast_files  --sql-template ${params.est_dir}/blastreduce/reduce-template.sql --fasta-length-parquet $fasta_length_parquet --duckdb-memory-limit ${params.duckdb_memory_limit} --sql-output-file reduce.sql
    module load DuckDB
    duckdb < reduce.sql
    """
}

process visualize_blast {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path blast_parquet
    output:
        path 'length.png'
        path 'pident.png'
        path 'edge.png'
        path 'evalue.tab'

    """
    module load Python
    module load efiest/python_est_1.0
    python ${params.est_dir}/visualization/process_blast_results.py --blast-output $blast_parquet --job-id 1 --length-plot-filename length --pident-plot-filename pident --edge-hist-filename edge --evalue-tab-filename evalue.tab --proxies sm:48
    """
}

workflow {
    // step 1: import sequences (stub that just copies the file)
    fasta_file = import_sequences(params.fasta_file)

    // step 2: create blastdb and frac seq file 
    // chunk_size = (int) Math.ceil(num_fasta_records / 256)
    fasta_lengths_parquet = blastreduce_transcode_fasta(fasta_file)
    // fasta_fractions = fasta_file | splitFasta(size: params.blast_shard_file_size, file: true)
    fasta_fractions = split_fasta(fasta_file)
    blastdb = create_blast_db(fasta_file)

    // step 3: all-by-all blast and blast reduce
    blast_fractions = all_by_all_blast(blastdb, fasta_fractions) | collect
    reduced_blast_parquet = blastreduce(blast_fractions, fasta_lengths_parquet)

    // step 4: visualize and save
    visualize_blast(reduced_blast_parquet)
}