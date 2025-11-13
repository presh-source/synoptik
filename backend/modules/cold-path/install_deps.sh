#!/bin/bash
set -e

# This script is called by Terraform's external data source to install Python dependencies.
# It ensures that dependencies are installed before the archive_file data source tries to zip them.

# The module path is passed as the first argument from Terraform.
MODULE_PATH=$1

if [ -z "$MODULE_PATH" ]; then
  echo "{\"error\": \"Module path argument is missing.\"}" >&2
  exit 1
fi

# Navigate to the module directory
cd "$MODULE_PATH"

# Define paths relative to the module directory
REQUIREMENTS_FILE="lambda/requirements.txt"
TARGET_DIR="lambda_build/python"

# Clean and create the target directory
rm -rf lambda_build
mkdir -p "$TARGET_DIR"

# Check if requirements.txt exists
if [ ! -f "$REQUIREMENTS_FILE" ]; then
  echo "{\"error\": \"$REQUIREMENTS_FILE not found.\"}" >&2
  exit 1
fi

# Install dependencies
pip install -r "$REQUIREMENTS_FILE" -t "$TARGET_DIR" --upgrade --quiet

# Output a JSON object to stdout to signal success to Terraform
echo "{\"success\": \"true\", \"timestamp\": \"$(date)\"}"
