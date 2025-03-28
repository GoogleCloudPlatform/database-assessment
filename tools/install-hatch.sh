#!/usr/bin/env bash
# Copyright 2024 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# --- Constants ---
BASE_URL="https://github.com/pypa/hatch/releases/latest/download"
EXTRACT_CMD="tar -xzf"

# --- Handle Optional Installation Directory ---
INSTALL_DIR="$1"  # Default: current directory
if [ -n "$INSTALL_DIR" ]; then
    if [ ! -d "$INSTALL_DIR" ]; then  # Check if directory exists
        INSTALL_DIR="$HOME/.local/bin"
        echo "Error: Invalid install directory '$INSTALL_DIR'"
        exit 1
    fi
    INSTALL_DIR=$(realpath "$INSTALL_DIR")  # Get absolute path
fi

# --- Determine Platform ---
PLATFORM=$(uname -s)
MACHINE=$(uname -m)
FILE_EXT="tar.gz"

if [ "$PLATFORM" = "Darwin" ]; then
    PLATFORM_NAME="apple-darwin"
elif [ "$PLATFORM" = "Linux" ]; then
    PLATFORM_NAME="unknown-linux-gnu"
    if [ "$MACHINE" = "aarch64" ]; then
        MACHINE="aarch64"
    fi
elif [ "$PLATFORM" = "Windows" ]; then
    PLATFORM_NAME="pc-windows-msvc"
    FILE_EXT="zip"
    EXTRACT_CMD="unzip"
else
    echo "Unsupported platform: $PLATFORM"
    exit 1
fi

# --- Construct File Name and URL ---
FILENAME="hatch-$MACHINE-$PLATFORM_NAME.$FILE_EXT"
URL="$BASE_URL/$FILENAME"

# --- Download and Extract ---
echo "Downloading Hatch binary: $FILENAME"
curl -L -o "$FILENAME" "$URL"

echo "Extracting to '$INSTALL_DIR'..."
$EXTRACT_CMD "$FILENAME" -C "$INSTALL_DIR"  # Extract to install directory
rm "$FILENAME"  # Remove archive

HATCH_BINARY="$INSTALL_DIR/hatch"  # Path to the extracted binary
if [ -x "$HATCH_BINARY" ]; then
    echo "Hatch binary successfully installed at '$HATCH_BINARY'"
else
    echo "Error: Hatch binary not found or not executable."
fi
