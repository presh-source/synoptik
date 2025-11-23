#!/bin/bash
set -e

SOURCE_PATH=$1
BUILD_PATH=$2

# Check if source path exists
if [ ! -d "$SOURCE_PATH" ]; then
  echo "Source path $SOURCE_PATH does not exist."
  exit 1
fi

# Create build directory
mkdir -p "$BUILD_PATH/python"

# Check for requirements.txt and install dependencies
if [ -f "$SOURCE_PATH/requirements.txt" ]; then
  echo "Installing dependencies from requirements.txt..."
  pip install \
    --platform manylinux2014_x86_64 \
    --implementation cp \
    --python-version 3.9 \
    --only-binary=:all: \
    -r "$SOURCE_PATH/requirements.txt" \
    -t "$BUILD_PATH/python"
else
  echo "No requirements.txt found. Skipping dependency installation."
fi

# Copy any other files from source
echo "Copying additional files from $SOURCE_PATH..."
rsync -a --exclude 'requirements.txt' "$SOURCE_PATH/" "$BUILD_PATH/python/"

echo "Build complete."

