
process all_by_all_blast {
    input:
        tuple val(fid), path(blast_db_files, arity: 5), val(blast_db_name), path(frac)

    output:
        tuple val(fid), path("${frac}.tab.sorted.parquet")

    script:
    """
    # run blast to get similarity metrics
    blastall \
        -p blastp \
        -i $frac \
        -d $blast_db_name \
        -m 8 \
        -e ${params.blast_evalue} \
        -b ${params.blast_num_matches} \
        -o ${frac}.tab

    # transcode to parquet for speed, creates frac.tab.parquet
    python $projectDir/../shared/axa_blast/transcode_blast.py --blast-output ${frac}.tab

    # in each row, ensure that qseqid < sseqid lexicographically
    DUCKDB_TEMP="${params.duckdb_temp_dir}/duckdb-${task.index}-"\$(date +%s)
    python $projectDir/../shared/axa_blast/render_prereduce_sql_template.py \
        --blast-output ${frac}.tab.parquet \
        --sql-template $projectDir/../shared/templates/prereduce-template.sql \
        --output-file ${frac}.tab.sorted.parquet \
        --duckdb-memory-limit ${params.duckdb_memory_limit} \
        --duckdb-temp-dir \${DUCKDB_TEMP} \
        --sql-output-file prereduce.sql
    duckdb < prereduce.sql
    """
}

process blastreduce_old {
    publishDir params.final_output_dir, mode: 'copy', enabled: !params.multiplex && params.sequence_version == "uniprot"

    input:
        tuple val(fid), path(blast_files), path(fasta_length_parquet)

    output:
        tuple val(fid), path("1.out.parquet")

    script:
    """
    DUCKDB_TEMP="${params.duckdb_temp_dir}/duckdb-${task.index}-"\$(date +%s)
    python $projectDir/../shared/blastreduce/render_reduce_sql_template.py \
        --blast-output $blast_files \
        --sql-template $projectDir/../shared/templates/reduce-template.sql \
        --fasta-length-parquet $fasta_length_parquet \
        --duckdb-memory-limit ${params.duckdb_memory_limit} \
        --duckdb-temp-dir \${DUCKDB_TEMP} \
        --sql-output-file allreduce.sql
    duckdb < allreduce.sql
    """
}

process blastreduce {
    publishDir params.final_output_dir, mode: 'copy', enabled: !params.multiplex && params.sequence_version == "uniprot"

    input:
        tuple val(fid), path(blast_files), path(fasta_length_parquet)

    output:
        tuple val(fid), path("1.out.parquet")

    script:
    """
    DUCKDB_TEMP="${params.duckdb_temp_dir}/duckdb-${task.index}-"\$(date +%s)
    python $projectDir/../shared/blastreduce/map_blast_reduce.py \
        --blast-output ${blast_files} \
        --fasta-length-parquet ${fasta_length_parquet} \
        --duckdb-memory-limit ${params.duckdb_memory_limit} \
        --duckdb-temp-dir \${DUCKDB_TEMP} \
        --output-file 1.out.parquet
    """
}

process blastreduce_transcode_fasta {
    input:
        tuple val(fid), path(fasta_file)

    output:
        tuple val(fid), path("${fasta_file.getName()}.parquet")

    script:
    """
    python $projectDir/../shared/blastreduce/transcode_fasta_lengths.py \
        --fasta $fasta_file \
        --output ${fasta_file.getName()}.parquet
    """
}

// Formerly known as multiplex
process condense_redundant {
    input:
        tuple val(fid), path(fasta_file)

    output:
        tuple val(fid), path("sequences.fasta"), emit: "fasta_file"
        tuple val(fid), path("sequences.fasta.clstr"), emit: "condensed"

    script:
    """
    cd-hit \
        -d 0 -c 1 -s 1 \
        -i ${fasta_file} \
        -o sequences.fasta \
        -M "${params.cdhit_memory_limit}"
    """
}

process create_blast_db {
    publishDir params.final_output_dir, mode: 'copy', pattern: "{database.*}"
    input:
        tuple val(fid), path(fasta_file)

    output:
        tuple val(fid), path("database.*"), val("database")

    script:
    """
    formatdb \
        -i $fasta_file \
        -n database \
        -p T -o T
    """
}

// Formerly known as demultiplex
process restore_condensed {
    publishDir params.final_output_dir, mode: 'copy', overwrite: true

    input:
        tuple val(fid), path(blast_parquet, stageAs: "reduced.parquet"), path(condensed)

    output:
        tuple val(fid), path("1.out.parquet")

    script:
    """
    DUCKDB_TEMP="${params.duckdb_temp_dir}/duckdb-${task.index}-"\$(date +%s)
    python $projectDir/../shared/condense/render_restore_sql_template.py \
        --blast-parquet $blast_parquet \
        --sql-template $projectDir/../shared/templates/restore-template.sql \
        --duckdb-memory-limit ${params.duckdb_memory_limit} \
        --duckdb-temp-dir \${DUCKDB_TEMP} \
        --sql-output-file restore.sql
    duckdb < restore.sql
    python $projectDir/../shared/condense/restore_condensed_sequences.py \
        --condensed-blast condensed.out \
        --restored-blast 1.out \
        --cd-hit-cluster ${condensed}
    python $projectDir/../shared/condense/transcode_restored_blast.py \
        --blast-output 1.out
    """
}

process split_fasta {
    input:
        tuple val(fid), path(fasta_file)

    output:
        tuple val(fid), path("parts/*.fasta")

    script:
    """
    mkdir parts
    seqkit split2 \
        ${fasta_file} \
        -p ${params.num_fasta_shards} \
        --out-dir parts
    """
}

