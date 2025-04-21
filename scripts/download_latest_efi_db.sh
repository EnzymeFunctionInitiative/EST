
remote_base="https://efi.igb.illinois.edu/downloads/databases/latest"

DIR=$1

file="blastdb.tar.gz"
python3 bin/download_file.py --remote-dir $remote_base/blastdb --remote-file $file --local-dir $DIR/temp_$file --local-file $DIR/$file
rm -rf $DIR/temp_$file
tar xzf $DIR/$file -C $DIR
rm $DIR/$file

file="diamonddb.tar.gz"
python3 bin/download_file.py --remote-dir $remote_base/diamonddb --remote-file $file --local-dir $DIR/temp_$file --local-file $DIR/$file
rm -rf $DIR/temp_$file
tar xzf $DIR/$file -C $DIR
rm $DIR/$file

file="efi_db.sqlite.gz"
python3 bin/download_file.py --remote-dir $remote_base/efi_db --remote-file $file --local-dir $DIR/temp_$file --local-file $DIR/$file
rm -rf $DIR/temp_$file
gunzip $DIR/$file

