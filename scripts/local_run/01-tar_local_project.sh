#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Resolve paths (ROBUST)
# -------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# scripts/local_run → project root = ../..
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PROJECT_NAME="$(basename "$PROJECT_ROOT")"
ARCHIVE_NAME="${PROJECT_NAME}.tar.gz"
ARCHIVE_PATH="${PROJECT_ROOT}/${ARCHIVE_NAME}"

# -------------------------------
# Excludes
# -------------------------------
EXCLUDES=(
  ".git"
  "__pycache__"
  "*.pyc"
  "outputs"
  "*.wav"
  "*.tar.gz"
)

# -------------------------------
# Tar
# -------------------------------
echo "📦 Creating archive: ${ARCHIVE_NAME}"
echo "📁 Project root: ${PROJECT_ROOT}"

TAR_EXCLUDES=()
for e in "${EXCLUDES[@]}"; do
  TAR_EXCLUDES+=( "--exclude=${e}" )
done

tar -czf "$ARCHIVE_PATH" \
  -C "$(dirname "$PROJECT_ROOT")" \
  "${TAR_EXCLUDES[@]}" \
  "$PROJECT_NAME"

echo "✅ Archive created: $ARCHIVE_PATH"
