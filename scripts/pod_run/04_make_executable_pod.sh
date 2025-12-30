#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Making all .sh files executable..."

chmod +x scripts/*.sh

echo "✅ All scripts are now executable"