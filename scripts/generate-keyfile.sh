#!/bin/bash

# Generate MongoDB keyfile for replica set authentication
# This script generates a random 756-character base64 encoded keyfile

KEYFILE_PATH="${1:-mongodb-keyfile}"

echo "Generating MongoDB keyfile..."
openssl rand -base64 756 > "$KEYFILE_PATH"

echo "Keyfile generated at: $KEYFILE_PATH"
echo "Please update the mongodb_keyfile_content variable in vars/mongodb-cluster.yml"
echo "with the contents of this file."

echo ""
echo "Example:"
echo "mongodb_keyfile_content: |"
cat "$KEYFILE_PATH" | sed 's/^/  /'