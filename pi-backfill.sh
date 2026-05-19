#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
DOTFILES_PI_DIR="${SCRIPT_DIR}/config/pi"

mkdir -p "$DOTFILES_PI_DIR"

copy_file() {
	local name="$1"
	local source="${PI_AGENT_DIR}/${name}"
	local destination="${DOTFILES_PI_DIR}/${name}"

	if [[ -f "$source" ]]; then
		cp -v "$source" "$destination"
	fi
}

copy_dir() {
	local name="$1"
	local source="${PI_AGENT_DIR}/${name}"
	local destination="${DOTFILES_PI_DIR}/${name}"

	if [[ -d "$source" ]]; then
		if [[ "$destination" != "$DOTFILES_PI_DIR"/* ]]; then
			echo "Refusing to remove unsafe path: ${destination}" >&2
			return 1
		fi

		rm -rf -- "${destination:?}"
		cp -Rv "$source" "$DOTFILES_PI_DIR/"
	fi
}

# Safe, portable Pi config files
for file in settings.json keybindings.json models.json AGENTS.md SYSTEM.md APPEND_SYSTEM.md; do
	copy_file "$file"
done

# Safe, portable Pi customization directories
for directory in prompts skills extensions themes; do
	copy_dir "$directory"
done

# Intentionally not copied: auth.json, sessions/, git/, npm/
