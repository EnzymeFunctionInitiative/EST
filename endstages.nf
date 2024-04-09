params.blast_output = "$baseDir/data/29897/blastout/*.fa.tab"
params.fasta_path = "$baseDir/data/29897/sequences.fa"

process blastreduce_transcode_blast {
    input:
    val blastfile
    output:
    path "${blastfile.getName()}.parquet"
    
    """
    python ~/code/EST/blastreduce/transcode_blast.py --blast-output $blastfile --transcoded-output ${blastfile.getName()}.parquet
    """
}

process blastreduce_transcode_fasta {
    input:
        val fasta_path
    output:
        path "${fasta_path.getName()}.parquet"

    """
    python ~/code/EST/blastreduce/transcode_fasta_lengths.py --fasta $fasta_path --output ${fasta_path.getName()}.parquet
    """
}

process blastreduce_reduce {
    input:
        path('*.fa.tab.parquet', arity: '1..*')
        path fastafile

    output:
        path '1.out.parquet'

    """
    python ~/code/EST/blastreduce/render_sql_template.py --blast-output *.fa.tab.parquet --sql-template ${baseDir}/blastreduce/reduce-template.sql --fasta-length-parquet $fastafile --sql-output-file reduce.sql
    duckdb < reduce.sql
    """
}

process visualize_blast {
    input:
        path blast_parquet
    output:
        path 'length.png'
        path 'pident.png'
        path 'edge.png'
        path 'evalue.tab'

    """
    python ${baseDir}/visualization/process_blast_results.py --blast-output $blast_parquet --job-id 1 --length-plot-filename length --pident-plot-filename pident --edge-hist-filename edge --evalue-tab-filename evalue.tab
    """
}

workflow {
    blast_files = Channel.fromPath(params.blast_output, checkIfExists: true)
    blast_parquet = blastreduce_reduce(blastreduce_transcode_blast(blast_files).toList(), blastreduce_transcode_fasta(file(params.fasta_path)))
    visualize_blast(blast_parquet)
}