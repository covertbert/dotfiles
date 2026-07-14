#!/usr/bin/env bash
# Manifest of all managed dotfile paths.
# Each entry: GROUP|TYPE|REPO_PATH|SYSTEM_PATH|IGNORE_KEYS
# TYPE: file | dir | json-merge
# REPO_PATH relative to DOTFILES_DIR
# SYSTEM_PATH absolute (uses env vars resolved at runtime)
# IGNORE_KEYS: only used by json-merge; comma-separated top-level keys to
#              keep on the system but never sync to/from the repo.

dotfiles_manifest() {
	local pi_dir="$1"
	local mcp_config="$2"
	local home="$3"

	# group | type | repo_path | system_path | ignore_keys
	cat <<EOF
config|file|config/git/.gitconfig|${home}/.gitconfig|
config|file|config/git/themes.gitconfig|${home}/themes.gitconfig|
config|file|config/terminal/starship.toml|${home}/.config/starship.toml|
config|file|config/terminal/.hyper.js|${home}/.hyper.js|
config|file|config/terminal/config.ghostty|${home}/Library/Application Support/com.mitchellh.ghostty/config|
config|file|config/zsh/.zshrc|${home}/.zshrc|
config|dir|config/zsh|${home}/.config/zsh|
pi|file|config/pi/AGENTS.md|${pi_dir}/AGENTS.md|
pi|json-merge|config/pi/settings.json|${pi_dir}/settings.json|lastChangelogVersion,defaultProvider,defaultModel,defaultThinkingLevel
pi|file|config/pi/models.json|${pi_dir}/models.json|
pi|file|config/pi/zsh-shell|${pi_dir}/zsh-shell|
pi|dir|config/pi/agents|${pi_dir}/agents|
pi|dir|config/pi/skills|${pi_dir}/skills|
pi|dir|config/pi/extensions|${pi_dir}/extensions|
pi|dir|config/pi/themes|${pi_dir}/themes|
pi|dir|config/pi/prompts|${pi_dir}/prompts|
service|file|services/pi-meridian/pi-meridian-proxy.mjs|${home}/.local/bin/pi-meridian-proxy.mjs|
service|file|services/pi-meridian/pi-meridian-stack.sh|${home}/.local/bin/pi-meridian-stack.sh|
service|file|services/pi-meridian/com.bertie.pi-meridian-stack.plist|${home}/Library/LaunchAgents/com.bertie.pi-meridian-stack.plist|
mcp|file|config/mcp/mcp.json|${mcp_config}|
EOF
}

# Optional files that only exist sometimes (no error if absent)
dotfiles_manifest_optional() {
	local pi_dir="$1"

	cat <<EOF
pi|file|config/pi/SYSTEM.md|${pi_dir}/SYSTEM.md|
pi|file|config/pi/APPEND_SYSTEM.md|${pi_dir}/APPEND_SYSTEM.md|
pi|file|config/pi/keybindings.json|${pi_dir}/keybindings.json|
EOF
}
