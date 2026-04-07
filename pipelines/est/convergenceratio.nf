
include { all_by_all_blast; blastreduce; blastreduce_transcode_fasta; condense_redundant; create_blast_db; restore_condensed; split_fasta } from "../est/subworkflows/all_by_all.nf"
include { unzip_ssn } from "../shared/nextflow/util.nf"
include { compute_clusters; get_id_list; get_ssn_id_info } from "../shared/nextflow/color_workflow.nf"

process compute_conv_ratio {
    input:
        tuple val(cluster_id), path(blast_parquet), path(fasta_file)

    output:
        path("${cluster_id}_conv_ratio.json")

    script:
    """
    python $projectDir/statistics/conv_ratio.py --blast-output ${blast_parquet} --fasta ${fasta_file} --output "${cluster_id}_conv_ratio.json"
    """
}

process merge_conv_ratios {
    publishDir params.final_output_dir, mode: "copy", pattern: "{conv_ratio.tab}"

    input:
        path stats_files

    output:
        path "conv_ratio.tab"

    script:
    """
    python $projectDir/statistics/merge_conv_ratios.py --stats ${stats_files} --output conv_ratio.tab
    """
}

process get_fasta_files {
    input:
        tuple val(cluster_id), path(id_file)

    output:
        tuple val(cluster_id), path("*.fasta", arity: "1")

    script:
    """
    base_filename=\$(basename $id_file .txt)
    fasta_file="\${base_filename}.fasta"
    perl $projectDir/../shared/perl/get_sequences.pl --fasta-db ${params.fasta_db} --sequence-ids-file ${id_file} --output-sequence-file \${fasta_file}
    """
}

process get_selected_id_lists {
    input:
        path uniprot_dir
        path uniref90_dir
        path uniref50_dir

    output:
        path "selected_ids/*.txt", emit: "id_files"

    script:
    """
    mkdir -p selected_ids

    if ls ${uniref50_dir}/*.txt 1> /dev/null 2>&1; then
        cp ${uniref50_dir}/*.txt selected_ids/
    elif ls ${uniref90_dir}/*.txt 1> /dev/null 2>&1; then
        cp ${uniref90_dir}/*.txt selected_ids/
    else
        cp ${uniprot_dir}/*.txt selected_ids/
    fi
    """
}

workflow {
    if (params.ssn_input =~ /\.zip$/) {
        ssn_file = unzip_ssn(params.ssn_input)
    } else {
        ssn_file = params.ssn_input
    }

    // Get the index and ID mapping tables and edgelist
    ssn_data = get_ssn_id_info(ssn_file)

    // Convert to value channel
    sequence_type_val = ssn_data.sequence_type.map { it.trim() }

    compute_info = compute_clusters(ssn_data.edgelist, ssn_data.index_seqid_map)

    id_list_data = get_id_list(compute_info.cluster_id_map, compute_info.singletons, ssn_data.seqid_source_map, sequence_type_val)

    input_seq_type_id_lists = get_selected_id_lists(id_list_data.uniprot_dir, id_list_data.uniref90_dir, id_list_data.uniref50_dir)

    cluster_id_lists = input_seq_type_id_lists 
            .flatten()
            .filter { file -> !file.name.contains("_All") }          // Don"t include the file with all sequences in the analysis
            .filter { file -> !file.name.contains("singleton") }     // Don"t include singletons in the analysis
            .map { file ->
                // Transform the file name into a cluster ID.  Removes "cluster_UniProt_" (or
                // "cluster_UniRefXX_") from the front if present
                def clean_id = file.simpleName.replaceAll(/^cluster_Uni(Prot|Ref90|Ref50)_/, "")
                return tuple(clean_id, file)
            }

    cluster_fasta = get_fasta_files(cluster_id_lists)
    // cluster_fasta is a channel of tuples of [clusterId, file]

    // Run a workflow that is nearly identical to the ALL_BY_ALL workflow in the est pipeline.
    reduced_fasta = condense_redundant(cluster_fasta)

    blast_databases = create_blast_db(reduced_fasta.fasta_file)

    fasta_lengths_parquet = blastreduce_transcode_fasta(cluster_fasta)

    fasta_shards = split_fasta(reduced_fasta.fasta_file)

    blast_input = blast_databases.combine(fasta_shards.transpose(), by: 0)

    blast_fractions = all_by_all_blast( blast_input ).groupTuple()

    reduced_blast_parquet = blastreduce(blast_fractions.join(fasta_lengths_parquet))

    // Expand redundant sequences after BLAST computation (formerly known as demultiplex)
    blast_parquet = restore_condensed(reduced_blast_parquet.join(reduced_fasta.condensed))

    stats_files = compute_conv_ratio(blast_parquet.combine(fasta_lengths_parquet, by: 0))

    merge_conv_ratios(stats_files.collect())
}

