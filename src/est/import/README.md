

Use these scripts to get a list of IDs to get FASTA sequences for.

An example:

    perl get_sequence_ids.pl --efi-config $EFI_CONFIG --efi-db $EFI_DB --output-dir $out_dir --mode family --family <FAMILY> --sequence-version uniprot
    perl get_sequences.pl --fasta-db <FASTA_DB_PATH> --output-dir $out_dir

    perl get_sequence_ids.pl --efi-config $EFI_CONFIG --efi-db $EFI_DB --output-dir $out_dir --mode family --fasta <USER_FASTA_FILE> --sequence-version uniprot
    perl import_fasta.pl --uploaded-fasta <USER_FASTA_FILE> --output-dir $out_dir

    perl get_sequence_ids.pl --efi-config $EFI_CONFIG --efi-db $EFI_DB --output-dir $out_dir --mode family --accessions <USER_ACCESSIONS_FILE> --sequence-version uniprot
    perl get_sequences.pl --fasta-db <FASTA_DB_PATH> --output-dir $out_dir

    perl get_sequence_ids.pl --efi-config $EFI_CONFIG --efi-db $EFI_DB --output-dir $out_dir --mode family --blast-query <USER_BLAST_QUERY_FILE> --sequence-version uniprot --blast-output blastfinal.tab
    perl get_sequences.pl --fasta-db <FASTA_DB_PATH> --output-dir $out_dir --blast-query <USER_BLAST_QUERY_FILE>

If `--output-dir` is not provided, the scripts assume that the files are to be output and read from the current working directory.

Optionally, the output files can be specified manually (see `lib/EFI/Import/Config/*.pm` for that syntax).

