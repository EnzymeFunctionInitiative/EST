

process unzip_files {
    errorStrategy "ignore"
    input:
        tuple val(file_name), path(zip_file), val(dir_name)
    output:
        tuple val(file_name), path("${file_name}.dat"), val(dir_name)
    """
    gunzip -f ${zip_file} > ${file_name}.dat
    """
}


process parse_embl {
    publishDir "${params.output_dir}/${dir_name}", pattern: "*.tab", mode: "copy"
    input:
        tuple val(file_name), path(dat_file), val(dir_name)
    output:
        path("${file_name}.tab")
    """
    mkdir -p ${params.output_dir}/${dir_name}
    module load Perl
    source /home/groups/efi/apps/perl_env.sh
    perl $projectDir/parse_embl.pl --input ${dat_file} --output ${file_name}.tab --config ${params.efi_config} --db-name ${params.efi_db}
    """
}


workflow {

    wgs_files = Channel.fromPath("${params.source_dir}/wgs/public/**/*.dat.gz")

    seq_files_all = Channel.fromPath("${params.source_dir}/sequence/**/*.dat.gz")
    seq_files = seq_files_all.filter { it =~ /(ENV|PRO|FUN|PHG)/ }

    sup_files = Channel.fromPath("${params.source_dir}/wgs/suppressed/**/*.dat.gz")

    merged_files = wgs_files.concat(seq_files, sup_files)
    merged_listing = merged_files.map { f -> [f.name.replaceFirst(/\.dat\.gz$/, ""), f, f.parent.parent.baseName + "/" + f.parent.baseName] }

    unzipped = unzip_files(merged_listing)

    parse_embl(unzipped)
}

