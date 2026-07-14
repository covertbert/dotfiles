#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ensure_homebrew() {
	local brew_bin=""

	if command -v brew &>/dev/null; then
		brew_bin="$(command -v brew)"
	elif [[ -x /opt/homebrew/bin/brew ]]; then
		brew_bin="/opt/homebrew/bin/brew"
	elif [[ -x /usr/local/bin/brew ]]; then
		brew_bin="/usr/local/bin/brew"
	else
		echo "==> Installing Homebrew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

		if [[ -x /opt/homebrew/bin/brew ]]; then
			brew_bin="/opt/homebrew/bin/brew"
		elif [[ -x /usr/local/bin/brew ]]; then
			brew_bin="/usr/local/bin/brew"
		fi
	fi

	if [[ -z "$brew_bin" ]]; then
		echo "Homebrew installation failed: brew not found." >&2
		return 1
	fi

	eval "$("$brew_bin" shellenv)"
}

echo "==> Installing dotfiles command..."
"${SCRIPT_DIR}/bin/dotfiles" install

ensure_homebrew

echo "==> Installing NVM and zgen..."
"${SCRIPT_DIR}/bin/dotfiles" installers --yes

echo "==> Installing Homebrew packages..."
"${SCRIPT_DIR}/bin/dotfiles" brew --yes

echo "==> Installing npm global packages..."
"${SCRIPT_DIR}/bin/dotfiles" npm --yes

echo "==> Deploying config files..."
"${SCRIPT_DIR}/bin/dotfiles" sync --to system --yes

echo "==> Applying macOS defaults..."
"${SCRIPT_DIR}/bin/dotfiles" defaults --yes

echo "==> Setting up Pi → Meridian service..."
"${SCRIPT_DIR}/bin/dotfiles" pi-meridian setup --yes

echo ""
echo "Bootstrap complete. Run 'dotfiles status' to verify."
echo "Optional private ZSH restore: dotfiles zsh-local setup"
