#!/usr/bin/env bash
# Deprecated: use 'dotfiles sync --to system' (mcp is included in manifest)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "mcp.sh is deprecated. Use: dotfiles sync --to system" >&2
echo ""
"${SCRIPT_DIR}/bin/dotfiles" sync --to system --yes
