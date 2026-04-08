
include { unzip_ssn } from "./util.nf"

cluster_data_dir = "cluster-data"


process get_id_list {
    input:
        path cluster_id_map
        path singletons
        path seqid_source_map
        val sequence_type

    output:
        path "cluster_sizes.txt", emit: "cluster_sizes"

        // Outputs for FASTA retrieval
        tuple val("uniprot"), path("uniprot/*.txt"), emit: "uniprot_tuples"
        tuple val("uniref90"), path("uniref90/*.txt", arity: "0..*"), emit: "uniref90_tuples"
        tuple val("uniref50"), path("uniref50/*.txt", arity: "0..*"), emit: "uniref50_tuples"
        tuple val("uniprot_domain"), path("uniprot_domain/*.txt", arity: "0..*"), emit: "uniprot_domain_tuples"
        tuple val("uniref90_domain"), path("uniref90_domain/*.txt", arity: "0..*"), emit: "uniref90_domain_tuples"
        tuple val("uniref50_domain"), path("uniref50_domain/*.txt", arity: "0..*"), emit: "uniref50_domain_tuples"

        // Output paths for zipping directories
        path "uniprot", emit: "uniprot_dir"
        path "uniref90", emit: "uniref90_dir"
        path "uniref50", emit: "uniref50_dir"
        path "uniprot_domain", emit: "uniprot_domain_dir"
        path "uniref90_domain", emit: "uniref90_domain_dir"
        path "uniref50_domain", emit: "uniref50_domain_dir"

    script:
    """
    # Always need to output these directories even if they're empty.  They will be excluded
    # from the zip process later if they are empty.
    mkdir -p ./uniprot ./uniref90 ./uniref50 ./uniprot_domain ./uniref90_domain ./uniref50_domain

    id_list_dir="."
    perl $projectDir/../shared/perl/get_id_lists.pl \
        --cluster-map ${cluster_id_map} \
        --singletons ${singletons} \
        --uniprot \$id_list_dir/uniprot \
        --uniref90 \$id_list_dir/uniref90 \
        --uniref50 \$id_list_dir/uniref50 \
        --seqid-source-map ${seqid_source_map} \
        --cluster-sizes cluster_sizes.txt \
        --sequence-type ${sequence_type} \
        --config ${params.efi_config} \
        --db-name ${params.efi_db}
    """
}


process get_fasta {
    input:
        tuple val(version), path(id_file)
        val sequence_type
        path domain_id_map

    // Output a tuple with the sequence version (e.g. uniprot, uniref50, uniref90) and the fasta file
    output:
        tuple val(version), path("*.fasta", arity: "1")

    script:
    // Check if the current file type matches the original SSN source ID type, and if so then
    // if a domain ID map file is provided, use domain ID mapping to obtain the domain-specific
    // portions of the sequences.
    def domain_map_arg = (version == sequence_type && domain_id_map.size() > 0) ? "--domain-id-map ${domain_id_map}" : ""

    """
    fasta_file="${id_file.baseName}.fasta"
    perl $projectDir/../shared/perl/get_sequences.pl \
        --fasta-db ${params.fasta_db} \
        --sequence-ids-file ${id_file} \
        ${domain_map_arg} \
        --output-sequence-file \${fasta_file}
    """
}


process get_ssn_id_info {
    input:
        path ssn_file

    output:
        path "edgelist.txt", emit: "edgelist"                   // Specifies the network, i.e. the edges between node network IDs
        path "index_seqid_map.txt", emit: "index_seqid_map"     // Maps node network ID to UniProt ID and the number of IDs in the metanode
        path "seqid_source_map.txt", emit: "seqid_source_map"   // Maps metanode IDs to UniProt IDs
        path "ssn_sequences.fasta", emit: "ssn_sequences"       // Custom sequences that are embedded in the SSN
        path "domain_id_map.txt", emit: "domain_id_map"         // Map of sequence ID to domain region
        env SEQ_TYPE, emit: sequence_type                       // Type of sequences that the SSN is based on (uniprot, uniref90, uniref50)

    script:
    """
    perl $projectDir/../shared/perl/ssn_to_id_list.pl \
        --ssn $ssn_file \
        --edgelist edgelist.txt \
        --index-seqid index_seqid_map.txt \
        --seqid-source-map seqid_source_map.txt \
        --ssn-sequences ssn_sequences.fasta \
        --sequence-type-file sequence_type.txt \
        --domain-id-map domain_id_map.txt
    SEQ_TYPE=\$(cat sequence_type.txt)
    """
}


process get_annotated_mapping_tables {
    publishDir params.final_output_dir, mode: "copy", pattern: "{mapping_table.txt,swissprot_clusters_desc.txt}"

    input:
        path cluster_id_map
        path seqid_source_map
        path cluster_color_map

    output:
        path "mapping_table.txt", emit: "mapping_table"
        path "swissprot_clusters_desc.txt", emit: "swissprot_table"

    script:
    """
    perl $projectDir/../shared/perl/annotate_mapping_table.pl \
        --seqid-source-map $seqid_source_map \
        --cluster-map $cluster_id_map \
        --cluster-color-map $cluster_color_map \
        --mapping-table mapping_table.txt \
        --swissprot-table swissprot_clusters_desc.txt \
        --config ${params.efi_config} \
        --db-name ${params.efi_db}
    """
}


process get_conv_ratio_table {
    publishDir params.final_output_dir, mode: "copy", pattern: "{conv_ratio.txt}"

    input:
        path edgelist
        path index_seqid_map
        path cluster_id_map
        path seqid_source_map

    output:
        path "conv_ratio.txt", emit: "conv_ratio"

    script:
    """
    perl $projectDir/../shared/perl/compute_conv_ratio.pl \
        --cluster-map $cluster_id_map \
        --index-seqid-map $index_seqid_map \
        --edgelist $edgelist \
        --seqid-source-map $seqid_source_map \
        --conv-ratio conv_ratio.txt
    """
}


process get_cluster_stats {
    input:
        path cluster_id_map
        path seqid_source_map
        path singletons

    output:
        path "color_workflow_stats.json", emit: "stats"

    script:
    """
    perl $projectDir/../shared/perl/compute_stats.pl \
        --cluster-map $cluster_id_map \
        --seqid-source-map $seqid_source_map \
        --singletons $singletons \
        --stats color_workflow_stats.json
    """
}


process compute_clusters {
    publishDir params.final_output_dir, mode: "copy", pattern: "{cluster_num_map.txt}"

    input:
        path edgelist
        path index_seqid_map

    output:
        path "cluster_id_map.txt", emit: "cluster_id_map"   // Mapping of node label to cluster number by node and cluster number by sequence
        path "singletons.txt", emit: "singletons"           // List of singletons
        path "cluster_num_map.txt", emit: "cluster_num_map" // Mapping of cluster number to cluster size

    script:
    """
    python $projectDir/../shared/python/compute_clusters.py \
        --edgelist $edgelist \
        --index-seqid-map $index_seqid_map \
        --clusters cluster_id_map.txt \
        --singletons singletons.txt \
        --cluster-num-map cluster_num_map.txt
    """
}


process assign_cluster_colors {
    input:
        path cluster_num_map

    output:
        path "cluster_colors.txt", emit: "cluster_colors"

    script:
    """
    perl $projectDir/../shared/perl/assign_cluster_colors.pl \
        --cluster-num-map ${cluster_num_map} \
        --cluster-color-map cluster_colors.txt
    """
}


process zip_id_directories {
    publishDir params.final_output_dir, mode: "copy"

    input:
        path dir_to_zip

    output:
        path "*.zip", optional: true

    script:
    """
    if [ -n "\$(ls -A ${dir_to_zip.name})" ]; then
        zip -r "ids_${dir_to_zip}.zip" "${dir_to_zip}"
    fi
    """
}


process zip_fasta_directories {
    publishDir params.final_output_dir, mode: "copy"

    input:
        tuple val(version_dir), path(fasta_files) // This looks like: ['uniprot', [file1.fasta, file2.fasta, ...]]

    output:
        path "fasta_${version_dir}.zip", optional: true

    script:
    """
    if [ -n "${fasta_files}" ]; then
        mkdir ${version_dir}
        cp *.fasta ${version_dir}/
        zip -r "fasta_${version_dir}.zip" "${version_dir}"
        rm -rf ${version_dir}
    fi
    """
}


workflow color_and_retrieve {
    main:
        if (params.ssn_input =~ /\.zip$/) {
            ssn_file = unzip_ssn(params.ssn_input)
        } else {
            ssn_file = params.ssn_input
        }

        //
        // STEP 1: PARSE THE SSN
        //

        // Get the index and ID mapping tables and edgelist
        ssn_data = get_ssn_id_info(ssn_file)

        // Convert to value channel
        sequence_type_val = ssn_data.sequence_type.map { it.trim() }

        // Compute the clusters
        compute_info = compute_clusters(ssn_data.edgelist, ssn_data.index_seqid_map)

        //
        // STEP 2: ID LISTS AND FASTA
        //

        // Get the list of sequence IDs from the SSN, grouped by ID type and cluster (e.g.
        // if the input SSN is UniRef50, there will be three outputs: uniprot/cluster_N.txt,
        // uniref90/cluster_N.txt, and uniref50/cluster_N.txt, with one cluster_N.txt file
        // for each cluster in the network)
        id_list_data = get_id_list(compute_info.cluster_id_map, compute_info.singletons, ssn_data.seqid_source_map, sequence_type_val)
        id_list = id_list_data.uniprot_tuples
                              .transpose()
                              .concat(id_list_data.uniref90_tuples.transpose(),
                                      id_list_data.uniref50_tuples.transpose(),
                                      id_list_data.uniprot_domain_tuples.transpose(),
                                      id_list_data.uniref90_domain_tuples.transpose(),
                                      id_list_data.uniref50_domain_tuples.transpose())

        // Get the FASTA files for each cluster
        fasta_files = get_fasta(id_list, sequence_type_val, ssn_data.domain_id_map)

        //
        // STEP 3: ASSIGN COLORS AND RETRIEVE METADATA
        //

        cluster_colors = assign_cluster_colors(compute_info.cluster_num_map)

        anno_tables = get_annotated_mapping_tables(compute_info.cluster_id_map, ssn_data.seqid_source_map, cluster_colors)

        //
        // STEP 4: COMPUTE STATS
        //

        cr_table = get_conv_ratio_table(ssn_data.edgelist, ssn_data.index_seqid_map, compute_info.cluster_id_map, ssn_data.seqid_source_map)

        cluster_data = get_cluster_stats(compute_info.cluster_id_map, ssn_data.seqid_source_map, compute_info.singletons)

        //
        // STEP 5: ZIP DIRECTORIES AND FILES
        //

        // Zip ID list by directory
        dirs_to_zip = id_list_data.uniprot_dir.mix(id_list_data.uniref90_dir,
                                                   id_list_data.uniref50_dir)
        zipped_id_dirs = zip_id_directories(dirs_to_zip)

        // Zip FASTA files by directory
        fasta_files
            .groupTuple()
            .set { grouped_fasta_ch }
        zipped_fasta_dirs = zip_fasta_directories(grouped_fasta_ch)

    emit:
        ssn_file
        mapping_table = anno_tables.mapping_table
        sp_clusters = anno_tables.swissprot_table
        cr_table
        cluster_stats = cluster_data.stats
        cluster_sizes = id_list_data.cluster_sizes
        cluster_num_map = compute_info.cluster_num_map
        cluster_id_map = compute_info.cluster_id_map
        singletons = compute_info.singletons
        metanode_map = ssn_data.seqid_source_map
        cluster_colors
        zipped_id_dirs
        zipped_fasta_dirs
        fasta_files
        sequence_type = sequence_type_val
}

