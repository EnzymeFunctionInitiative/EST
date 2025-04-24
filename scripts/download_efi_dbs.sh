#!/bin/bash

# loop over input arguments
for (( index=1; index <= $#; index++ ))
do
	# get the next argument's index
	idx=$((index+1))
	# check if this argument matches a parameter string
	if [[ ${!index} == '--help' ]]; then
		echo "Usage: bash scripts/download_efi_dbs.sh.sh [--data-dir /path --source-url URL]

    Description:
        Download the required EFI Databases from the provided source URL, saving the files to an output directory. 

    Options:
        --data-dir      path to the test dataset; default: ./data/efi
        --source-url    a URL web address from which the tar/zip files of the databases will be sourced
			default: https://efi.igb.illinois.edu/downloads/databases/latest
        --help          prints this message
"
		exit
	# check if this argument matches a parameter string
	elif [[ ${!index} == "--data-dir" ]]; then
		# grab the value of the next argument and save it in a var
		DIR="${!idx}"
		echo "Writing database files to $DIR"
	elif [[ ${!index} == "--source-url" ]]; then
		# grab the value of the next argument and save it in a var
		remote_base="${!idx}"
		echo "Gathering the databases from $remote_base"
	fi
done 

# apply default values if input arguments are not given
if [[ -z "$DIR" ]]; then
	DIR="$(pwd)/data/efi"
	echo "Writing database files to $DIR"
fi

if [[ -z "$remote_base" ]]; then
	remote_base="https://efi.igb.illinois.edu/downloads/databases/latest"
	echo "Gathering the databases from $remote_base"
fi

# gather the BLAST database and untar it
file="blastdb.tar.gz"
python3 bin/download_file.py --remote-dir $remote_base/blastdb --remote-file $file --local-dir $DIR/temp_$file --local-file $DIR/$file
rm -rf $DIR/temp_$file
tar xzf $DIR/$file -C $DIR
rm $DIR/$file

# gather the DIAMOND database and untar it
file="diamonddb.tar.gz"
python3 bin/download_file.py --remote-dir $remote_base/diamonddb --remote-file $file --local-dir $DIR/temp_$file --local-file $DIR/$file
rm -rf $DIR/temp_$file
tar xzf $DIR/$file -C $DIR
rm $DIR/$file

# gather the EFI DB SQLite file and gunzip it
file="efi_db.sqlite.gz"
python3 bin/download_file.py --remote-dir $remote_base/efi_db --remote-file $file --local-dir $DIR/temp_$file --local-file $DIR/$file
rm -rf $DIR/temp_$file
gunzip $DIR/$file

