
// Require the same FASTA file that was used to generate the BLAST computation results provided in blast_input
params.blast_input = null
params.cdhit_input = null

// Validate inputs immediately
if (!params.blast_input) {
    error "❌ Error: --blast_input parameter is missing.\nUsage: nextflow run verify_cluster_expand_mux.nf --blast_input <BLAST_FILE> --cdhit_input <CDHIT_CLUSTER_FILE>"
}
if (!params.cdhit_input) {
    error "❌ Error: --cdhit_input parameter is missing.\nUsage: nextflow run verify_cluster_expand_mux.nf --blast_input <BLAST_FILE> --cdhit_input <CDHIT_CLUSTER_FILE>"
}

old_scripts = "${projectDir}/../../legacy_est"

process run_perl_demux {
    input:
        path blastin
        path clusters
    output:
        path "perl_output.tsv"
    
    """
    perl ${old_scripts}/est/mux/demux.pl -blastin $blastin -blastout perl_output.tsv -cluster $clusters
    """
}

process run_python_expand {
    input:
        path blastin
        path clusters
    output:
        path "python_output.tsv"
    
    """
    python ${projectDir}/../est/cluster/expand_clusters.py --clustered-blast $blastin --expanded-blast python_output.tsv --cd-hit-cluster $clusters
    """
}

process compare_outputs {
    debug true // Print output to console
    input:
        path perl_out
        path python_out
    
    """
    # Sort both files to ensure line order doesn't cause a false failure
    sort $perl_out > sorted_perl.tsv
    sort $python_out > sorted_python.tsv
    
    # Diff returns 0 if files are identical, 1 if different
    if diff sorted_perl.tsv sorted_python.tsv > diff_result.txt; then
        echo "✅ SUCCESS: Python refactor produces identical output to Perl."
    else
        echo "❌ FAILURE: Outputs differ."
        echo "See diff_result.txt for details."
        head -n 10 diff_result.txt
        exit 1
    fi
    """
}

workflow {
    blast_ch = Channel.fromPath(params.blast_input)
    cdhit_ch = Channel.fromPath(params.cdhit_input)

    perl_out = run_perl_demux(blast_ch, cdhit_ch)
    python_out = run_python_expand(blast_ch, cdhit_ch)
    
    compare_outputs(perl_out, python_out)
}

