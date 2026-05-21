#!/usr/bin/env bash
# Deprecated: use 'dotfiles brew'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "brew.sh is deprecated. Use: dotfiles brew" >&2
echo ""
"${SCRIPT_DIR}/bin/dotfiles" brew --yes
