
include { all_by_all_blast; blastreduce; blastreduce_transcode_fasta; condense_redundant; create_blast_db; restore_condensed; split_fasta } from "../est/subworkflows/all_by_all.nf"
include { unzip_ssn } from "../shared/nextflow/util.nf"
include { compute_clusters; get_conv_ratio_table; get_id_list; get_ssn_id_info } from "../shared/nextflow/color_workflow.nf"

process compute_blast_conv_ratio {
    input:
        tuple val(cluster_id), path(blast_parquet), path(fasta_file)

    output:
        path("${cluster_id}_conv_ratio.json")

    script:
    """
    python $projectDir/statistics/conv_ratio.py \
        --blast-output ${blast_parquet} \
        --fasta ${fasta_file} \
        --output "${cluster_id}_conv_ratio.json"
    """
}

process merge_conv_ratios {
    publishDir params.final_output_dir, mode: "copy", pattern: "{conv_ratio.tab}"

    input:
        path stats_files
        path cr_table

    output:
        path "conv_ratio.tab"

    script:
    """
    python $projectDir/statistics/merge_conv_ratios.py \
        --ssn-conv-ratio ${cr_table} \
        --stats ${stats_files} \
        --output conv_ratio.tab
    """
}

process get_fasta_files {
    input:
        tuple val(cluster_id), path(id_file)

    output:
        tuple val(cluster_id), path("*.fasta", arity: "1")

    script:
    """
    perl $projectDir/../shared/perl/get_sequences.pl \
        --fasta-db ${params.fasta_db} \
        --sequence-ids-file ${id_file} \
        --output-sequence-file "${id_file.baseName}.fasta"
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

    //
    // STEP 1: GET ID LISTS AND COMPUTE CLUSTERS
    //

    ssn_data = get_ssn_id_info(ssn_file)

    compute_info = compute_clusters(ssn_data.edgelist, ssn_data.index_seqid_map)

    // Convert the sequence type to a value channel
    sequence_type_val = ssn_data.sequence_type.map { it.trim() }

    id_list_data = get_id_list(compute_info.cluster_id_map, compute_info.singletons, ssn_data.seqid_source_map, sequence_type_val)

    // Get the ID lists that will be used, e.g. the original sequences from the SSN
    input_seq_type_id_lists = get_selected_id_lists(id_list_data.uniprot_dir, id_list_data.uniref90_dir, id_list_data.uniref50_dir)

    //
    // STEP 2: OBTAIN THE FASTA FILES
    //

    // Get the cluster IDs from the file names
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

    // Get FASTA files; the return value is a channel of tuples of [clusterId, file]
    cluster_fasta = get_fasta_files(cluster_id_lists)

    //
    // STEP 3: RUN THE EST-BASED ALL-BY-ALL WORKFLOW
    // Run a workflow that is nearly identical to the ALL_BY_ALL workflow in the est pipeline.
    // See the workflow for more information on how this works.
    //

    reduced_fasta = condense_redundant(cluster_fasta)

    blast_databases = create_blast_db(reduced_fasta.fasta_file)

    fasta_lengths_parquet = blastreduce_transcode_fasta(cluster_fasta)

    fasta_shards = split_fasta(reduced_fasta.fasta_file)

    blast_input = blast_databases.combine(fasta_shards.transpose(), by: 0)

    blast_fractions = all_by_all_blast(blast_input).groupTuple()

    reduced_blast_parquet = blastreduce(blast_fractions.join(fasta_lengths_parquet))

    // Expand redundant sequences after BLAST computation (formerly known as demultiplex)
    blast_parquet = restore_condensed(reduced_blast_parquet.join(reduced_fasta.condensed))

    //
    // STEP 4: COMPUTE CONVERGENCE RATIOS
    //

    // Compute the convergence ratio based on the edges and nodes in each cluster
    cr_table = get_conv_ratio_table(ssn_data.edgelist, ssn_data.index_seqid_map, compute_info.cluster_id_map, ssn_data.seqid_source_map)

    // Compute the convergence ratio based on the BLAST results
    //stats_files = compute_blast_conv_ratio(blast_parquet.combine(fasta_lengths_parquet, by: 0))
    //stats_files = compute_blast_conv_ratio(reduced_blast_parquet.combine(fasta_lengths_parquet, by: 0))
    stats_files = compute_blast_conv_ratio(reduced_blast_parquet.join(fasta_lengths_parquet))

    // Merge the data for all the clusters into one file
    merge_conv_ratios(stats_files.collect(), cr_table)
}

