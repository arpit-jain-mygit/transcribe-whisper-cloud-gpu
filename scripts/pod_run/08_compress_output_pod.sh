#!/usr/bin/env bash
set -euo pipefail

ts() { date +"%Y-%m-%d %H:%M:%S"; }

# ============================================================
# RESOLVE PATHS
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

OUTPUTS_DIR="$PROJECT_ROOT/outputs"
ARCHIVE="$PROJECT_ROOT/outputs.tar.gz"

echo "============================================================"
echo "📦 [$(ts)] Compressing outputs"
echo "Project root : $PROJECT_ROOT"
echo "Outputs dir  : $OUTPUTS_DIR"
echo "Archive      : $ARCHIVE"
echo "============================================================"

# ============================================================
# VALIDATION
# ============================================================
if [[ ! -d "$OUTPUTS_DIR" ]]; then
  echo "❌ ERROR: outputs directory does not exist"
  echo "👉 Expected: $OUTPUTS_DIR"
  exit 1
fi

if [[ -z "$(ls -A "$OUTPUTS_DIR")" ]]; then
  echo "❌ ERROR: outputs directory is empty"
  echo "👉 Nothing to compress"
  exit 1
fi

# ============================================================
# COMPRESS
# ============================================================
tar -czf "$ARCHIVE" -C "$PROJECT_ROOT" outputs

echo "============================================================"
echo "✅ [$(ts)] outputs.tar.gz created successfully"
echo "============================================================"
