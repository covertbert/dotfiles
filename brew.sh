#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREW_DIR="${SCRIPT_DIR}/brew"

if ! command -v brew &>/dev/null; then
	echo "Homebrew not installed. Installing now..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if ! command -v brew &>/dev/null; then
	if [[ -x /opt/homebrew/bin/brew ]]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	elif [[ -x /usr/local/bin/brew ]]; then
		eval "$(/usr/local/bin/brew shellenv)"
	fi
fi

if ! command -v brew &>/dev/null; then
	echo "Homebrew install completed, but brew is not available on PATH." >&2
	exit 1
fi

brew bundle --verbose --file="${BREW_DIR}/Brewfile"
brew bundle --verbose --file="${BREW_DIR}/Caskfile"

if [[ -x "$(brew --prefix)/opt/fzf/install" ]]; then
	"$(brew --prefix)"/opt/fzf/install --all
fi
