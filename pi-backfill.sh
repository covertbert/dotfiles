#!/usr/bin/env bash
# Deprecated: use 'dotfiles sync --to repo' or 'dotfiles backfill'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "pi-backfill.sh is deprecated. Use: dotfiles backfill" >&2
echo ""
"${SCRIPT_DIR}/bin/dotfiles" sync --to repo --yes
