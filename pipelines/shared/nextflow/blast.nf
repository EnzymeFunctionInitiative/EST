
process all_by_all_blast {
    label 'TASK_axa'

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
        -a ${task.cpus} \
        -o ${frac}.tab

    # transcode to parquet for speed, creates frac.tab.parquet
    python $projectDir/../shared/axa_blast/transcode_blast.py --blast-output ${frac}.tab

    # in each row, ensure that qseqid < sseqid lexicographically
    DUCKDB_TEMP="${params.duckdb_temp_dir}/duckdb-${task.index}-"\$(date +%s)
    python $projectDir/../shared/axa_blast/render_prereduce_sql_template.py \
        --blast-output ${frac}.tab.parquet \
        --sql-template $projectDir/../shared/templates/prereduce-template.sql \
        --output-file ${frac}.tab.sorted.parquet \
        --duckdb-memory-limit "${task.memory.toGiga()}GB" \
        --duckdb-n-threads ${task.cpus} \
        --duckdb-temp-dir \${DUCKDB_TEMP} \
        --sql-output-file prereduce.sql
    duckdb < prereduce.sql
    rm -Rf \${DUCKDB_TEMP}
    """
}

process blastreduce_old {
    label 'APP_duckdb'

    publishDir params.final_output_dir, mode: 'copy', enabled: (!params.multiplex || params.sequence_version != "uniprot")

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
        --duckdb-memory-limit "${task.memory.toGiga()}GB" \
        --duckdb-n-threads ${task.cpus} \
        --duckdb-temp-dir \${DUCKDB_TEMP} \
        --sql-output-file allreduce.sql
    duckdb < allreduce.sql
    rm -Rf \${DUCKDB_TEMP}
    """
}

process blastreduce {
    label 'APP_duckdb'

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
        --duckdb-memory-limit "${task.memory.toGiga()}GB" \
        --duckdb-n-threads ${task.cpus} \
        --duckdb-temp-dir \${DUCKDB_TEMP} \
        --output-file 1.out.parquet
    rm -Rf \${DUCKDB_TEMP}
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
    label 'APP_cd_hit'

    input:
        tuple val(fid), path(fasta_file)

    output:
        tuple val(fid), path("sequences.fasta"), emit: "fasta_file"
        tuple val(fid), path("sequences.fasta.clstr"), emit: "condensed"

    script:
    """
    cd-hit -d 0 -c 1 -s 1 \
           -i ${fasta_file} \
           -o sequences.fasta \
           -M ${task.memory.toMega()} \
           -T ${task.cpus}
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
process restore_condensed_old {
    label 'APP_duckdb'

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
        --duckdb-memory-limit "${task.memory.toGiga()}GB" \
        --duckdb-n-threads ${task.cpus} \
        --duckdb-temp-dir \${DUCKDB_TEMP} \
        --sql-output-file restore.sql
    duckdb < restore.sql
    rm -Rf \${DUCKDB_TEMP}
    python $projectDir/../shared/condense/restore_condensed_sequences_old.py \
        --condensed-blast condensed.out \
        --restored-blast 1.out \
        --cd-hit-cluster ${condensed}
    python $projectDir/../shared/condense/transcode_restored_blast.py \
        --blast-output 1.out
    """
}

process restore_condensed {
    label 'APP_duckdb'

    publishDir params.final_output_dir, mode: 'copy', overwrite: true

    input:
        tuple val(fid), path(blast_parquet, stageAs: "reduced.parquet"), path(condensed)

    output:
        tuple val(fid), path("1.out.parquet")

    script:
    """
    # python script
    DUCKDB_TEMP="${params.duckdb_temp_dir}/duckdb-${task.index}-"\$(date +%s)
    python $projectDir/../shared/condense/restore_condensed_sequences.py \
        --cd-hit-cluster ${condensed} \
        --condensed-blast reduced.parquet \
        --output-file 1.out.parquet \
        --duckdb-memory-limit "${task.memory.toGiga()}GB" \
        --duckdb-n-threads ${task.cpus} \
        --duckdb-temp-dir \${DUCKDB_TEMP}
    rm -Rf \${DUCKDB_TEMP}
    """
}

process remove_self_alignments {
    label 'APP_duckdb'

    publishDir params.final_output_dir, mode: 'copy', overwrite: true

    input:
        tuple val(fid), path(blast_parquet, stageAs: "reduced.parquet")

    output:
        tuple val(fid), path("1.out.parquet")

    script:
    """
    # python script
    DUCKDB_TEMP="${params.duckdb_temp_dir}/duckdb-${task.index}-"\$(date +%s)
    python $projectDir/../shared/condense/remove_self_alignments.py \
        --condensed-blast reduced.parquet \
        --output-file 1.out.parquet \
        --duckdb-memory-limit "${task.memory.toGiga()}GB" \
        --duckdb-n-threads ${task.cpus} \
        --duckdb-temp-dir \${DUCKDB_TEMP}
    rm -Rf \${DUCKDB_TEMP}
    """
}

process sort_and_split_fasta {
    input:
        tuple val(fid), path(fasta_file)

    output:
        tuple val(fid), path("parts/*.fasta")

    script:
    def sort_str = params.sort_seq_by_length ? "--by-length" : "--by-name"
    """
    mkdir parts
    seqkit sort ${sort_str} \
        --reverse \
        --two-pass \
        --threads ${task.cpus} \
        ${fasta_file} \
        | seqkit split2 \
        --threads ${task.cpus} \
        -p ${params.num_fasta_shards} \
        --out-dir parts \
        --out-prefix "all_sequences.fasta_"
    """
}

