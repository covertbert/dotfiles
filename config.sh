#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

copy_file() {
	local source="$1"
	local destination="$2"

	if [[ ! -f "$source" ]]; then
		echo "Missing file: ${source}" >&2
		return 1
	fi

	mkdir -p "$(dirname "$destination")"
	cp -v "$source" "$destination"
}

copy_file_if_missing() {
	local source="$1"
	local destination="$2"

	if [[ ! -e "$destination" ]]; then
		copy_file "$source" "$destination"
	fi
}

copy_file_if_exists() {
	local source="$1"
	local destination="$2"

	if [[ -f "$source" ]]; then
		copy_file "$source" "$destination"
	fi
}

copy_dir() {
	local source="$1"
	local destination_parent="$2"

	if [[ ! -d "$source" ]]; then
		echo "Missing directory: ${source}" >&2
		return 1
	fi

	mkdir -p "$destination_parent"
	cp -Rv "$source" "$destination_parent/"
}

copy_dir_if_exists() {
	local source="$1"
	local destination_parent="$2"

	if [[ -d "$source" ]]; then
		copy_dir "$source" "$destination_parent"
	fi
}

install_nvm_if_missing() {
	if command -v nvm &>/dev/null || [[ -s "${NVM_DIR}/nvm.sh" ]]; then
		return 0
	fi

	echo "NVM not installed. Installing now..."
	curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
}

install_zgen_if_missing() {
	local zgen_directory="${HOME}/.zgen"

	if [[ ! -d "$zgen_directory" ]]; then
		git clone https://github.com/tarjoilija/zgen.git "$zgen_directory"
	fi
}

install_nvm_if_missing
install_zgen_if_missing

# Git config
copy_file "${CONFIG_DIR}/git/.gitconfig" "${HOME}/.gitconfig"
copy_file "${CONFIG_DIR}/git/themes.gitconfig" "${HOME}/themes.gitconfig"
copy_file_if_missing "${CONFIG_DIR}/git/user.gitconfig" "${HOME}/user.gitconfig"

# Terminal and shell config
copy_file "${CONFIG_DIR}/terminal/starship.toml" "${HOME}/.config/starship.toml"
copy_file "${CONFIG_DIR}/zsh/.zshrc" "${HOME}/.zshrc"
copy_dir "${CONFIG_DIR}/zsh" "${HOME}/.config"
copy_file "${CONFIG_DIR}/terminal/.hyper.js" "${HOME}/.hyper.js"

# Pi config
mkdir -p "$PI_AGENT_DIR"

for file in settings.json keybindings.json models.json plannotator.json AGENTS.md SYSTEM.md APPEND_SYSTEM.md zsh-shell; do
	copy_file_if_exists "${CONFIG_DIR}/pi/${file}" "${PI_AGENT_DIR}/${file}"
done

for directory in prompts skills extensions themes; do
	copy_dir_if_exists "${CONFIG_DIR}/pi/${directory}" "$PI_AGENT_DIR"
done

"${SCRIPT_DIR}/mcp.sh"
