#!/bin/bash

# ------------------------------------------------------------------
# common.sh
# Shared setup for verification scripts.
# Sources this file to ensure test data is present before running tests.
# ------------------------------------------------------------------

# 1. Determine the absolute path of the directory containing this script.
#    This ensures paths work regardless of where you call the script from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DATA_DIR="${SCRIPT_DIR}/test_data"

# 2. Create the test_data directory if it doesn't exist
if [ ! -d "$TEST_DATA_DIR" ]; then
    echo "Creating test data directory at: $TEST_DATA_DIR"
    mkdir -p "$TEST_DATA_DIR"
fi

# ------------------------------------------------------------------
# Function: ensure_test_data
# Usage: ensure_test_data "URL" "ARCHIVE_NAME" "EXPECTED_FOLDER"
#
# Arguments:
#   1. URL: The link to download the file.
#   2. ARCHIVE_NAME: The name of the file being downloaded (e.g., data.tar.gz).
#   3. EXPECTED_FOLDER: The folder name created when the archive is unpacked.
#                       Used to skip download if data already exists.
# ------------------------------------------------------------------
ensure_test_data() {
    local url="$1"
    local archive_name="$2"
    local expected_folder="$3"
    
    local target_path="${TEST_DATA_DIR}/${expected_folder}"
    local archive_path="${TEST_DATA_DIR}/${archive_name}"

    # Check if the unzipped data already exists
    if [ -d "$target_path" ]; then
        echo "✅ Test data found in ${target_path}. Skipping download."
        return 0
    fi

    echo "⚠️  Test data not found at ${target_path}."
    echo "⬇️  Downloading from ${url}..."

    # Download (try wget, fall back to curl)
    if command -v wget >/dev/null 2>&1; then
        wget -q --show-progress -O "$archive_path" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "$archive_path" "$url"
    else
        echo "❌ Error: Neither wget nor curl is installed."
        exit 1
    fi

    # Check if download succeeded
    if [ ! -f "$archive_path" ]; then
        echo "❌ Error: Download failed."
        exit 1
    fi

    echo "📦 Unpacking ${archive_name}..."
    
    # Unpack based on extension
    case "$archive_name" in
        *.tar.gz|*.tgz)
            tar -xzf "$archive_path" -C "$TEST_DATA_DIR"
            ;;
        *.zip)
            unzip -q "$archive_path" -d "$TEST_DATA_DIR"
            ;;
        *)
            echo "❌ Error: Unsupported archive format: $archive_name"
            exit 1
            ;;
    esac

    # Cleanup archive
    rm "$archive_path"

    # Verify unpack
    if [ -d "$target_path" ]; then
        echo "✅ Setup complete."
    else
        echo "❌ Error: Unpacking finished, but expected directory '${expected_folder}' was not found."
        echo "   Did the archive unpack into a different folder name?"
        exit 1
    fi
}
