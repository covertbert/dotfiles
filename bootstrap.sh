#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing dotfiles command..."
"${SCRIPT_DIR}/bin/dotfiles" install

echo "==> Installing NVM and zgen..."
"${SCRIPT_DIR}/bin/dotfiles" installers --yes

echo "==> Deploying config files..."
"${SCRIPT_DIR}/bin/dotfiles" sync --to system --yes

echo "==> Applying macOS defaults..."
"${SCRIPT_DIR}/bin/dotfiles" defaults --yes

echo "==> Installing Homebrew packages..."
"${SCRIPT_DIR}/bin/dotfiles" brew --yes

echo "==> Installing npm global packages..."
"${SCRIPT_DIR}/bin/dotfiles" npm --yes

echo ""
echo "Bootstrap complete. Run 'dotfiles status' to verify."
