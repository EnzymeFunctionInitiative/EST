
include { unzip_ssn } from "../shared/nextflow/unzip.nf"
include { get_ssn_id_info; compute_clusters } from "../shared/nextflow/color_workflow.nf"
include { get_sequences; split_sequence_ids; multiplex } from "../shared/nextflow/sequence.nf"

process cat_fasta_files {
    input:
        path fasta_files
        path ssn_sequences
    output:
        path "all_sequences.fasta"
    script:
    input = fasta_files.toSorted().join(" ")
    """
    cat ${input} > all_sequences.fasta
    if [[ -s "${ssn_sequences}" ]]; then
        cat ${ssn_sequences} >> all_sequences.fasta
    fi
    """
}

process get_accession_ids {
    input:
        path cluster_id_map
        path singletons
    output:
        path "accession_ids.txt"
    """
    # Use awk to skip the header line
    cut -f1 ${cluster_id_map} | awk '{if(NR>1)print}' > accession_ids.txt
    awk '{if(NR>1)print}' ${singletons} >> accession_ids.txt
    """
}

process get_unique_accession_ids {
    input:
        path cluster_id_map
        path cdhit_clusters
    output:
        path "unique_cluster_id_map.txt", emit: "cluster_id_map"
        path "unique_sequence_ids.txt", emit: "accession"
    """
    python $projectDir/get_unique_cdhit_ids.py --cdhit-file ${cdhit_clusters} --cluster-id-map ${cluster_id_map} --unique-cluster-id-map unique_cluster_id_map.txt --unique-sequence-ids unique_sequence_ids.txt
    """
}

process cgfp_identify {
    input:
        path fasta_file
    output:
        path "shortbred_markers.faa", emit "markers"
        path "id_temp/clust/clust.faa.clstr", emit "marker_clusters"
    """
    #TODO: these can be optional
    cdhit_sid_arg="--clustid ${params.cdhit_sid}"
    cons_thresh_arg="--consthresh ${params.cons_thresh}"
    sense_arg="--diamond-sensitivity ${params.diamond_sense}"
    python $projectDir/shortbred_identify.py --threads ${params.num_threads} -goi ${fasta_file} --refdb ${params.fasta_db} \
        --search_program ${params.search_program} \$cdhit_sid_arg \$cons_thresh_arg \$sense_arg \
        --markers shortbred_markers.faa --tmp id_temp 
    """
}

process get_swissprot_tables {
    publishDir params.final_output_dir, mode: "copy"
    input:
        path cluster_id_map
        path singletons
    output:
        path "swissprot_clusters.tab", emit: "clusters"
        path "swissprot_singletons.tab", emit: "singletons"
    """
    perl $projectDir/../shared/perl/annotate_mapping_table.pl --cluster-map ${cluster_id_map} \
        --swissprot-table swissprot_clusters.tab \
        --config ${params.efi_config} --db-name ${params.efi_db}
    perl $projectDir/../shared/perl/annotate_mapping_table.pl --cluster-map ${singletons} \
        --swissprot-table swissprot_singletons.tab \
        --config ${params.efi_config} --db-name ${params.efi_db}
    """
}

process create_metadata {
    input:
        path cluster_id_map
        path singletons
        path cluster_num_map
        path seqid_source_map
        path marker_clusters
        path markers
        path unique_ids
        path full_fasta_file
            compute_info.cluster_id_map, compute_info.singletons, compute_info.cluster_num_map,
            ssn_data.seqid_source_map, identify.marker_clusters, identify.markers,
            unique_ids.accession, full_fasta_file, unique_ids)
    output:
        path "metadata.tab", emit: "metadata"
    """
    perl $projectDir/compute_stats.pl --cluster-id-map ${cluster_id_map} --singletons ${singletons} --cluster-num-map ${cluster_num_map} \
        --seqid-source-map ${seqid_source_map} --marker-clusters ${marker_clusters} --markers {$markers} --unique-ids ${unique_ids} \
        --all-sequences ${full_fasta_file} --min-seq-len ${params.min_seq_len} --max-seq-len ${params.max_seq_len} \
        --metadata metadata.tab
    """
}

process make_cdhit_table {
    input:
        path cluster_id_map
        path marker_clusters
    output:
        path "cdhit.txt", emit: "cdhit"
    """
    perl $projectDir/make_cdhit_table.pl --cluster-map ${cluster_id_map} --marker-clusters ${marker_clusters} --table cdhit.txt
    """
}

process make_ssn {
    input:
        path orig_ssn
        path markers
        path cluster_id_map
        path cdhit_table
    output:
        path "ssn_identify_markers.xgmml", emit: "ssn_markers"
    """
    perl $projectDir/make_ssn.pl --ssn-in ${orig_ssn} --ssn-out ssn_identify_markers.xgmml --markers ${markers} \
        --cluster-id-map ${cluster_id_map} --cdhit-table ${cdhit_table}
    """
}

workflow identify {
    main:
        if (params.ssn_input =~ /\.zip$/) {
            ssn_file = unzip_ssn(params.ssn_input)
        } else {
            ssn_file = params.ssn_input
        }

        // Get the index and ID mapping tables and edgelist
        ssn_data = get_ssn_id_info(ssn_file)

        // Compute the clusters
        compute_info = compute_clusters(ssn_data.edgelist, ssn_data.index_seqid_map)

        //TODO: check if there are any clusters (i.e. has it gone through the color SSN utility)

        // Get the FASTA file
        //TODO: make sure that this dies if there are no sequences
        full_accession_ids = get_accession_ids(compute_info.cluster_id_map, compute_info.singletons)

        // Retrieve fasta files, Nextflow may do this in parallel
        accession_shards = split_sequence_ids(full_accession_ids, params.num_accession_shards)
        full_fasta_files = get_sequences(accession_shards.flatten(), params.fasta_db)

        // Add the SSN (e.g. unidentified) sequences to the fasta file
        full_fasta_file = cat_fasta_files(full_fasta_files.collect(), ssn_data.ssn_sequences)

        //TODO: min/max seq len

        // Remove redundant sequences
        mux_files = multiplex(full_fasta_file)
        unique_ids = get_unique_accession_ids(compute_info.cluster_id_map, mux_files.clusters)

        identify = cgfp_identify(mux_files.fasta_file)

        swissprot_tables = get_swissprot_tables(compute_info.cluster_id_map, compute_info.singletons)

        metadata_file = create_metadata(
            compute_info.cluster_id_map, compute_info.singletons, compute_info.cluster_num_map,
            ssn_data.seqid_source_map, identify.marker_clusters, identify.markers,
            unique_ids.accession, full_fasta_file)

        cdhit_table = make_cdhit_table(unique_ids.cluster_id_map, identify.marker_clusters)

        identify_ssn = make_ssn(ssn_file, identify.markers, unique_ids.cluster_id_map, cdhit_table)

        identify_ssn_zip = zip_file(identify_ssn)

    emit:
        identify.markers
        identify_ssn_zip
        swissprot_tables.clusters
        swissprot_tables.singletons
        metadata_file
        cdhit_table
}

