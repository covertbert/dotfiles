#!/usr/bin/env bash
# Deprecated: use 'dotfiles sync --to system' or 'dotfiles deploy'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "config.sh is deprecated. Use: dotfiles sync --to system" >&2
echo ""
"${SCRIPT_DIR}/bin/dotfiles" installers --yes
"${SCRIPT_DIR}/bin/dotfiles" sync --to system --yes
