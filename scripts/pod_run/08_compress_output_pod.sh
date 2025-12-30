#!/usr/bin/env bash
set -e

tar -cvzf outputs.tar.gz -C /workspace outputs
echo "✅ outputs.tar.gz created successfully"
