process get_sequence_ids {
    output:
        path 'accession_ids.txt', emit: 'accession_ids'
        path 'import_stats.json', emit: 'import_stats'
        path 'sequence_metadata.tab', emit: 'sequence_metadata'
        path 'sunburst_ids.tab', emit: 'sunburst_ids'
        path 'blast_hits.tab', emit: 'blast_hits'
    stub:
    """
    cp $existing_fasta_file allsequences.fa
    """
    script:
    common_args = "--efi-config ${params.efi_config} --efi-db ${params.efi_db} --mode ${params.import_mode} --sequence-version ${params.family_id_format}"
    if (params.import_mode == "family") {
        """
        perl $projectDir/src/est/import/get_sequence_ids.pl $common_args --family ${params.families}
        """
    } else if (params.import_mode == "accessions") {
        """
        perl $projectDir/src/est/import/get_sequence_ids.pl $common_args --user-accession-file ${params.accessions_file}
        """
    } else if (params.import_mode == "blast") {
        // blast_hits.tab is provided as an output to the user
        """
        blastall -p blastp -i ${params.blast_query_file} -d ${params.fasta_db} -m 8 -e ${params.blast_evalue} -b ${params.num_blast_matches} -o init.blast
        SZ=\$(wc -c "init.blast" | cut -d' ' -f1)
        if [[ \$SZ != 0 ]]; then
            cat init.blast | grep -v '#' | cut -f 1,2,3,4,12 | sort -k5,5nr > init_blast.tab
            cat init.blast | grep -v '#' | cut -f 2,11 | sort -k2nr > blast_hits.tab
            perl $projectDir/src/est/import/get_sequence_ids.pl $common_args --blast-output init_blast.tab --blast-query ${params.blast_query_file}
        else
            echo "BLAST Failed. Check input sequence."
        fi
        """
    } else {
        error "Mode '${params.import_mode}' not yet implemented"
    }
}

process split_sequence_ids {
    input:
        path accessions_file
    output:
        path "accession_ids.txt.part*"
    """
    split -d -e -n r/${params.num_accession_shards} $accessions_file accession_ids.txt.part
    """
}

process get_sequences {
    input:
        path accession_ids
    output:
        path "${accession_ids}.fasta"
    stub:
    """
    cp $existing_fasta_file all_sequences.fasta
    """
    script:
    """
    perl $projectDir/src/est/import/get_sequences.pl --fasta-db ${params.fasta_db} --sequence-ids-file $accession_ids --output-sequence-file ${accession_ids}.fasta
    """
}

process cat_fasta_files {
    input:
        path fasta_files
    output:
        path 'all_sequences.fasta'
    script:
    input = fasta_files.toSorted().join(" ")
    """
    cat $input > all_sequences.fasta
    """
    if (params.import_mode == "blast") {
        """
        perl $projectDir/src/est/import/append_blast_query.pl --blast-query-file ${params.blast_query_file} --output-sequence-file all_sequences.fasta
        """
    }
}

process import_fasta {
    output:
        path "all_sequences.fasta", emit: "fasta_file"
        path 'accession_ids.txt', emit: 'accession_ids'
        path 'import_stats.json', emit: 'import_stats'
        path 'sequence_metadata.tab', emit: 'sequence_metadata'
        path 'sunburst_ids.tab', emit: 'sunburst_ids'
        path 'seq_mapping.tab', emit: 'mapping_file'

    """
    # produces a mapping.txt file
    perl $projectDir/src/est/import/get_sequence_ids.pl --efi-config ${params.efi_config} --efi-db ${params.efi_db} --mode fasta --user-fasta-file ${params.uploaded_fasta_file}
    perl $projectDir/src/est/import/import_fasta.pl --uploaded-fasta ${params.uploaded_fasta_file}
    """
}

process multiplex {
    input:
        path fasta_file
    output:
        path 'sequences.fasta', emit: 'fasta_file'
        path 'sequences.fasta.clstr', emit: 'clusters'
    """
    cd-hit -d 0  -c 1 -s 1 -i $fasta_file -o sequences.fasta -M 10000
    """
}

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

process split_fasta {
    input:
        path fasta_file
    output:
        path "fracfile-*.fa"
    """
    perl $projectDir/src/est/split_fasta/split_fasta.pl -parts ${params.num_fasta_shards} -source ${fasta_file}
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
    blastall -p blastp -i $frac -d $blast_db_name -m 8 -e ${params.blast_evalue} -b ${params.num_blast_matches} -o ${frac}.tab

    # transcode to parquet for speed, creates frac.tab.parquet
    python $projectDir/src/est/axa_blast/transcode_blast.py --blast-output ${frac}.tab

    # in each row, ensure that qseqid < sseqid lexicographically
    python $projectDir/src/est/axa_blast/render_prereduce_sql_template.py --blast-output ${frac}.tab.parquet --sql-template $projectDir/templates/prereduce-template.sql --output-file ${frac}.tab.sorted.parquet --duckdb-temp-dir /scratch/duckdb-${params.job_id} --sql-output-file prereduce.sql
    duckdb < prereduce.sql
    """
}

process blastreduce_transcode_fasta {
    input:
        path fasta_file
    output:
        path "${fasta_file.getName()}.parquet"

    """
    python $projectDir/src/est/blastreduce/transcode_fasta_lengths.py --fasta $fasta_file --output ${fasta_file.getName()}.parquet
    """
}

process blastreduce {
    input:
        path blast_files
        path fasta_length_parquet

    output:
        path "1.out.parquet"

    """
    python $projectDir/src/est/blastreduce/render_reduce_sql_template.py --blast-output $blast_files  --sql-template $projectDir/templates/reduce-template.sql --fasta-length-parquet $fasta_length_parquet --duckdb-memory-limit ${params.duckdb_memory_limit} --duckdb-temp-dir /scratch/duckdb-${params.job_id} --sql-output-file allreduce.sql
    duckdb < allreduce.sql
    """
}

process demultiplex {
    input:
        path blast_parquet
        path clusters
    output:
        path '1.out.parquet'
    """
    echo "COPY (SELECT * FROM read_parquet('$blast_parquet')) TO 'mux.out' (FORMAT CSV, DELIMITER '\t', HEADER false);" | duckdb
    perl $projectDir/src/est/mux/demux.pl -blastin mux.out -blastout 1.out -cluster $clusters
    python $projectDir/src/est/mux/transcode_demuxed_blast.py --blast-output 1.out
    """
}

process compute_stats {
    input:
        path blast_parquet
        path fasta_file
    output:
        path "boxplot_stats.parquet", emit: boxplot_stats
        path "evalue.tab", emit: evaluetab
        path "acc_counts.json", emit: acc_counts
    """
    # compute convergence ratio
    python $projectDir/src/est/statistics/conv_ratio.py --blast-output $blast_parquet --fasta $fasta_file --output acc_counts.json

    # compute boxplot stats and evalue.tab
    python $projectDir/src/est/statistics/render_boxplotstats_sql_template.py --blast-output $blast_parquet --duckdb-temp-dir /scratch/duckdb-${params.job_id} --boxplot-stats-output boxplot_stats.parquet --evalue-output evalue.tab --sql-template $projectDir/templates/boxplotstats-template.sql --sql-output-file boxplotstats.sql
    duckdb < boxplotstats.sql
    """
}

process visualize {
    input:
        path boxplot_stats
    output:
        path '*.png'

    """
    python $projectDir/src/est/visualization/plot_blast_results.py --boxplot-stats $boxplot_stats --job-id ${params.job_id} --length-plot-filename length --pident-plot-filename pident --edge-hist-filename edge --proxies sm:48
    """
}

process finalize_output {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path accession_ids
        path fasta_file
        path import_stats
        path sequence_metadata
        path sunburst_ids
        path blast_output
        path plots
        path evalue_tab
        path acc_counts
    output:
        path accession_ids
        path fasta_file
        path import_stats
        path sequence_metadata
        path sunburst_ids
        path blast_output
        path plots
        path evalue_tab
        path acc_counts
    """
    echo 'Finalizing'
    """
}

workflow {
    // step 1: import sequence ids using params

    if (params.import_mode == "fasta") {
        fasta_import_files = import_fasta()
        fasta_file = fasta_import_files.fasta_file
        sequence_id_files = fasta_import_files
    } else {
        sequence_id_files = get_sequence_ids()

        // split up the sequence ID list into separate files so we can parallelize the
        // process of retrieving sequences from the BLAST sequence database
        accession_shards = split_sequence_ids(sequence_id_files.accession_ids)
        fasta_file = cat_fasta_files(get_sequences(accession_shards.flatten()).collect())
    }

    // step 2: multiplex
    if (params.multiplex) {
        multiplex_files = multiplex(fasta_file)
        fasta_file = multiplex_files.fasta_file
    }

    // step 2: create blastdb and frac seq file 
    blastdb = create_blast_db(fasta_file)
    fasta_lengths_parquet = blastreduce_transcode_fasta(fasta_file)

    // step 3: all-by-all blast and blast reduce
    fasta_shards = split_fasta(fasta_file)
    blast_fractions = all_by_all_blast(blastdb.database_files, blastdb.database_name, fasta_shards.flatten()) | collect
    reduced_blast_parquet = blastreduce(blast_fractions, fasta_lengths_parquet)

    // demultiplex
    if (params.multiplex) {
        reduced_blast_parquet = demultiplex(reduced_blast_parquet, multiplex_files.clusters)
    }

    // step 4: compute convergence ratio and boxplot stats
    stats = compute_stats(reduced_blast_parquet, fasta_lengths_parquet)

    // step 5: visualize
    plots = visualize(stats.boxplot_stats)

    // step 6: copy files to output dir
    finalize_output(sequence_id_files.accession_ids, fasta_file, sequence_id_files.import_stats, sequence_id_files.sequence_metadata, sequence_id_files.sunburst_ids, reduced_blast_parquet, plots, stats.evaluetab, stats.acc_counts)
}
