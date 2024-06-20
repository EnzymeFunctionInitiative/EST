

Use these scripts to get a list of IDs to get FASTA sequences for.

An example:

    perl get_sequence_ids.pl --efi-config $EFI_CONFIG --efi-db $EFI_DB --output-dir $out_dir --mode family --family <FAMILY> --sequence-version uniprot
    perl get_sequences.pl --fasta-db <FASTA_DB_PATH> --output-dir $out_dir


If `--output-dir` is not provided, the scripts assume that the files are to be output and read from the current working directory.

Optionally, the output files can be specified manually (see `lib/EFI/Import/Config.pm` for that syntax).

