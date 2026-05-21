#!/usr/bin/env bash
# Deprecated: use 'dotfiles defaults'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "defaults.sh is deprecated. Use: dotfiles defaults" >&2
echo ""
"${SCRIPT_DIR}/bin/dotfiles" defaults --yes
