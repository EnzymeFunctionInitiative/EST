
# This is an example of how to download a test dataset.
# This script must be run from the EST root directory.

test_env="sqlite"
test_data_dir="$PWD/tests/test_data"
test_data_dir_env="$test_data_dir/$test_env"
if [[ -d "$test_data_dir_env" ]]; then
    echo "$test_data_dir_env already exists; delete it first or use a different directory"
    exit 1
fi
mkdir -p $test_data_dir

file_name="$test_env.tar.gz"
remote_dir="https://efi.igb.illinois.edu/downloads/databases/test_datasets"
url="$remote_dir/$file_name"
local_file="$test_data_dir/$file_name"

echo "Fetching sample data from $url to $local_file"
curl -sL $url > $local_file

tar xvfz $local_file -C "$test_data_dir"

mg_test_data_dir="$test_data_dir/metagenome"
mg_sample_file="metagenome_sample.tar.gz"
mg_url="$remote_dir/$mg_sample_file"
mg_local_file="$test_data_dir/$mg_sample_file"

echo "Fetching sample metagenome database from $mg_url to $mg_local_file"
curl -sL $mg_url > $mg_local_file

tar xvfz $mg_local_file -C "$mg_test_data_dir"

