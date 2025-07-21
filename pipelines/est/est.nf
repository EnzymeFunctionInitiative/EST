
include { get_sequences; split_sequence_ids; multiplex } from "../shared/nextflow/sequence.nf"

process get_source_ids {
    publishDir params.final_output_dir, mode: 'copy'
    output:
        path 'source_ids.tab', emit: 'source_ids'
        path 'source_seq.tab', emit: 'source_meta'
        path 'source_stats.json', emit: 'source_stats'
        path 'blast_hits.tab', optional: true
        path 'seq_mapping.tab', emit: 'seq_mapping', optional: true
        path 'unmatched_id.tab', optional: true
    script:

    common_args = "--efi-config ${params.efi_config} --efi-db ${params.efi_db} --mode ${params.import_mode} --sequence-version ${params.sequence_version}"

    family_args = ""
    if (params.families) {
        family_args = "--family " + params.families
    }

    if (params.domain) {
        family_args = family_args + " --domain " + params.domain
        if (params.domain_family) {
            family_args = family_args + " --domain-family " + params.domain_family
        }
    }

    if (params.import_mode == "blast") {
        // blast_hits.tab is provided as an output to the user
        """
        blastall -p blastp -i ${params.blast_query_file} -d ${params.import_blast_fasta_db} -m 8 -e ${params.import_blast_evalue} -b ${params.import_blast_num_matches} -o init_blast.out
        if [[ -s init_blast.out ]]; then
            awk '! /^#/ {print \$2"\t"\$11}' init_blast.out | sort -k2nr > blast_hits.tab
        else
            echo "BLAST did not return any matches.  Verify that the sequence is a protein and not a nucleotide sequence."
            exit 1
        fi
        perl $projectDir/import/get_sequence_ids.pl $common_args $family_args --blast-output init_blast.out --blast-query ${params.blast_query_file}
        """
    } else if (params.import_mode == "accessions") {
        """
        perl $projectDir/import/get_sequence_ids.pl $common_args $family_args --accessions ${params.accessions_file}
        """
    } else if (params.import_mode == "fasta") {
        """
        perl $projectDir/import/get_sequence_ids.pl $common_args $family_args --fasta ${params.uploaded_fasta_file} --seq-mapping-file seq_mapping.tab
        """
    } else if (params.import_mode == "family") {
        """
        perl $projectDir/import/get_sequence_ids.pl $common_args $family_args
        """
    } else {
        error "Mode '${params.import_mode}' not yet implemented"
    }
}

process filter_ids {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path source_ids     // table of all sequence IDs, including UniRef IDs
        path source_meta    // sequence metdata
        path source_stats   // statistics of source import process
    output:
        path 'accession_table.tab', emit: 'accession_table'     // table of all sequence IDs, including UniRef IDs, filtered
        path 'sequence_metadata.tab', emit: 'sequence_metadata' // sequence metdata in metadata format
        path 'import_stats.json', emit: 'import_stats'          // final statistics of source and filter import processes
        path 'retrieval_ids.tab', emit: 'retrieval_ids'         // list of IDs that came from the database, as opposed to user-specified FASTA files, including domain data
    script:
    filter_args = ""
    if (params.filter) {
        filter_args = params.filter.join(" --filter ")
        filter_args = "--filter ${filter_args}"
    }
    """
    perl $projectDir/import/filter_ids.pl --efi-config ${params.efi_config} --efi-db ${params.efi_db} --sequence-version ${params.sequence_version} $filter_args
    """
}

process get_sunburst_data {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path accession_table
        path sequence_metadata
    output:
        path 'sunburst_tax.json'
    script:
    """
    perl $projectDir/import/get_sunburst_data.pl --efi-config ${params.efi_config} --efi-db ${params.efi_db}
    """
}

process cat_fasta_files {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path '*.fasta'
    output:
        path 'all_sequences.fasta'
    script:
    cat_cmd = "cat *.fasta > all_sequences.fasta"
    if (params.import_mode == "blast") {
        """
        $cat_cmd
        perl $projectDir/import/append_blast_query.pl --blast-query-file ${params.blast_query_file} --output-sequence-file all_sequences.fasta
        """
    } else {
        cat_cmd
    }
}

process import_fasta {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path sequence_metadata
        path seq_mapping
    output:
        path "imported_sequences.fasta", emit: "fasta_file"
    """
    perl $projectDir/import/import_fasta.pl --uploaded-fasta ${params.uploaded_fasta_file} --seq-mapping-file ${seq_mapping} --output-sequence-file imported_sequences.fasta
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
    perl $projectDir/split_fasta/split_fasta.pl -parts ${params.num_fasta_shards} -source ${fasta_file}
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
    python $projectDir/axa_blast/render_prereduce_sql_template.py --blast-output ${frac}.tab.parquet --sql-template $projectDir/templates/prereduce-template.sql --output-file ${frac}.tab.sorted.parquet --duckdb-temp-dir /scratch/duckdb-${params.job_id} --sql-output-file prereduce.sql
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

process blastreduce {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path blast_files
        path fasta_length_parquet

    output:
        path "1.out.parquet"

    """
    python $projectDir/blastreduce/render_reduce_sql_template.py --blast-output $blast_files  --sql-template $projectDir/templates/reduce-template.sql --fasta-length-parquet $fasta_length_parquet --duckdb-memory-limit ${params.duckdb_memory_limit} --duckdb-temp-dir /scratch/duckdb-${params.job_id} --sql-output-file allreduce.sql
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
    echo "COPY (SELECT * FROM read_parquet('$blast_parquet')) TO 'mux.out' (FORMAT CSV, DELIMITER '\t', HEADER false);" | duckdb
    perl $projectDir/mux/demux.pl -blastin mux.out -blastout 1.out -cluster $clusters
    python $projectDir/mux/transcode_demuxed_blast.py --blast-output 1.out
    """
}

process compute_stats {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path blast_parquet
        path fasta_file
        path import_stats
    output:
        path "boxplot_stats.parquet", emit: boxplot_stats
        path "evalue.tab", emit: evaluetab
        path "stats.json", emit: final_stats
    """
    # compute convergence ratio
    python $projectDir/statistics/conv_ratio.py --blast-output $blast_parquet --fasta $fasta_file --output conv_ratio.json

    python $projectDir/statistics/merge_stats.py --import-stats $import_stats --conv-ratio-stats conv_ratio.json --output stats.json

    # compute boxplot stats and evalue.tab
    python $projectDir/statistics/render_boxplotstats_sql_template.py --blast-output $blast_parquet --duckdb-temp-dir /scratch/duckdb-${params.job_id} --boxplot-stats-output boxplot_stats.parquet --evalue-output evalue.tab --sql-template $projectDir/templates/boxplotstats-template.sql --sql-output-file boxplotstats.sql
    duckdb < boxplotstats.sql
    """
}

process visualize {
    publishDir params.final_output_dir, mode: 'copy'
    input:
        path boxplot_stats
    output:
        path '*.png'

    """
    python $projectDir/visualization/plot_blast_results.py --boxplot-stats $boxplot_stats --job-id ${params.job_id} --length-plot-filename length --pident-plot-filename pident --edge-hist-filename edge --proxies sm:48
    """
}

workflow {

    // Step 1: import sequence ids using params

    // We get sequence IDs and basic metadata from the input source, including those in FASTA files
    source_data = get_source_ids()

    // Filter on all sequence IDs including UniRef, and including IDs in FASTA files
    sequence_id_files = filter_ids(source_data.source_ids, source_data.source_meta, source_data.source_stats)

    // Get sunburst data for all sequence IDs, after filtering
    get_sunburst_data(sequence_id_files.accession_table, sequence_id_files.sequence_metadata)

    // Split up the sequence ID list into separate files to enable parallel sequence retrieval
    // from the BLAST sequence database.  If the import mode is FASTA, then these IDs are only
    // ones that come from adding a family to the job
    accession_shards = split_sequence_ids(sequence_id_files.retrieval_ids, params.num_accession_shards)
    fasta_files = get_sequences(accession_shards.flatten(), params.fasta_db)

    // If importing FASTA file, reformat the FASTA file and create the file that will be added to
    // the dataset for all-by-all BLAST
    if (params.import_mode == "fasta") {
        // sequence metadata is used to ensure that any sequences that were filtered out in a
        // prior step are also removed when rewriting the user fasta
        import_fasta_file = import_fasta(sequence_id_files.sequence_metadata, source_data.seq_mapping)
        fasta_files = fasta_files.concat(import_fasta_file)
    }

    fasta_file = cat_fasta_files(fasta_files.collect())

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

    // Step 5: compute convergence ratio and boxplot stats
    stats = compute_stats(reduced_blast_parquet, fasta_lengths_parquet, sequence_id_files.import_stats)

    // Step 6: visualize
    plots = visualize(stats.boxplot_stats)
}
