
include { multiplex } from "../../shared/nextflow/sequence.nf"

process create_blast_db {
    input:
        path fasta_file
    output:
        path "database.*", emit: 'database_files'
        val "database", emit: 'database_name'
    """
    formatdb -i $fasta_file -n database -p T -o T
    """
}

process all_by_all_blast {
    input:
        path(blast_db_files, arity: 5)
        val blast_db_name
        path frac
    output:
        path "${frac}.tab.sorted.parquet"
    """
    # run blast to get similarity metrics
    blastall -p blastp -i $frac -d $blast_db_name -m 8 -e ${params.blast_evalue} -b ${params.blast_num_matches} -o ${frac}.tab

    # transcode to parquet for speed, creates frac.tab.parquet
    python $projectDir/axa_blast/transcode_blast.py --blast-output ${frac}.tab

    # in each row, ensure that qseqid < sseqid lexicographically
    python $projectDir/axa_blast/render_prereduce_sql_template.py --blast-output ${frac}.tab.parquet --sql-template $projectDir/templates/prereduce-template.sql --output-file ${frac}.tab.sorted.parquet --duckdb-memory-limit "${params.duckdb_memory_limit}" --duckdb-temp-dir /scratch/duckdb-"${params.job_id}"  --sql-output-file prereduce.sql
    duckdb < prereduce.sql
    """
}

process blastreduce_transcode_fasta {
    input:
        path fasta_file
    output:
        path "${fasta_file.getName()}.parquet"

    """
    python $projectDir/blastreduce/transcode_fasta_lengths.py --fasta $fasta_file --output ${fasta_file.getName()}.parquet
    """
}

process split_fasta {
    input:
        path fasta_file
    output:
        path "fracfile-*.fa"
    """
    perl $projectDir/split_fasta/split_fasta.pl -parts ${params.num_fasta_shards} -source ${fasta_file}
    """
}

process blastreduce {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path blast_files
        path fasta_length_parquet

    output:
        path "1.out.parquet"

    """
    python $projectDir/blastreduce/render_reduce_sql_template.py --blast-output $blast_files  --sql-template $projectDir/templates/reduce-template.sql --fasta-length-parquet $fasta_length_parquet --duckdb-memory-limit "${params.duckdb_memory_limit}" --duckdb-temp-dir /scratch/duckdb-"${params.job_id}" --sql-output-file allreduce.sql
    duckdb < allreduce.sql
    """
}

process demultiplex {
    publishDir params.final_output_dir, mode: 'copy', overwrite: true
    input:
        path blast_parquet
        path clusters
    output:
        path '1.out.parquet'
    """
    echo "SET memory_limit = '${params.duckdb_memory_limit}'; SET temp_directory = '/scratch/duckdb-${task.hash}'; SET threads TO 1; COPY (SELECT * FROM read_parquet('$blast_parquet')) TO 'mux.out' (FORMAT CSV, DELIMITER '\t', HEADER false);" | duckdb
    perl $projectDir/mux/demux.pl -blastin mux.out -blastout 1.out -cluster $clusters
    python $projectDir/mux/transcode_demuxed_blast.py --blast-output 1.out
    """
}

workflow ALL_BY_ALL {
    take:
        fasta_file

    main:
        // Step 2: multiplex
        if (params.multiplex) {
            multiplex_files = multiplex(fasta_file)
            fasta_file = multiplex_files.fasta_file
        }

        // Step 3: create blastdb and frac seq file 
        blastdb = create_blast_db(fasta_file)
        fasta_lengths_parquet = blastreduce_transcode_fasta(fasta_file)

        // Step 4: all-by-all blast and blast reduce
        fasta_shards = split_fasta(fasta_file)
        blast_fractions = all_by_all_blast(blastdb.database_files, blastdb.database_name, fasta_shards.flatten()) | collect
        reduced_blast_parquet = blastreduce(blast_fractions, fasta_lengths_parquet)

        // Demultiplex
        if (params.multiplex) {
            reduced_blast_parquet = demultiplex(reduced_blast_parquet, multiplex_files.clusters)
        }

    emit:
        fasta_lengths_parquet = fasta_lengths_parquet
        blast_parquet = reduced_blast_parquet 
}

