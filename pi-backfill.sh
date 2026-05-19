#!/usr/bin/env bash

set -euo pipefail

PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
DOTFILES_PI_DIR="./config/pi"

mkdir -p "$DOTFILES_PI_DIR"

copy_file() {
	local name="$1"
	if [[ -f "$PI_AGENT_DIR/$name" ]]; then
		cp -rv "$PI_AGENT_DIR/$name" "$DOTFILES_PI_DIR/$name"
	fi
}

copy_dir() {
	local name="$1"
	if [[ -d "$PI_AGENT_DIR/$name" ]]; then
		rm -rf "$DOTFILES_PI_DIR/$name"
		cp -rv "$PI_AGENT_DIR/$name" "$DOTFILES_PI_DIR/"
	fi
}

# Safe, portable Pi config files
copy_file "settings.json"
copy_file "keybindings.json"
copy_file "models.json"
copy_file "AGENTS.md"
copy_file "SYSTEM.md"
copy_file "APPEND_SYSTEM.md"

# Safe, portable Pi customization directories
copy_dir "prompts"
copy_dir "skills"
copy_dir "extensions"
copy_dir "themes"

# Intentionally not copied: auth.json, sessions/, git/, npm/
