rimraf() {
	find . -name 'node_modules' -type d -prune -exec rm -rf '{}' +
}

setSecret() {
	secretName=$1

	if [[ -z $secretName ]]; then
		echo "Missing secret name"
	else
		currentSeceret=$(op get item "$secretName" --fields credential)
		export "$secretName"="$currentSeceret"
		echo "Set variable with key $secretName"
	fi
}

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export NVM_DEFAULT_VERSION="${NVM_DEFAULT_VERSION:-24}"

# Keep one NVM global bin on PATH. Falling through old Node patch versions can
# make a command appear installed even when it is missing under the active Node.
__set_single_nvm_bin_on_path() {
	local node_bin="${1:h}" entry
	local -a cleaned_path

	for entry in "${path[@]}"; do
		if [[ "$entry" != "$NVM_DIR"/versions/node/*/bin ]]; then
			cleaned_path+=("$entry")
		fi
	done

	path=("$node_bin" "${cleaned_path[@]}")
}

__find_nvmrc_upwards() {
	local dir="${1:-$PWD}"

	while [ "$dir" != "/" ]; do
		if [ -f "$dir/.nvmrc" ]; then
			echo "$dir/.nvmrc"
			return 0
		fi

		dir="${dir:h}"
	done

	if [ -f "/.nvmrc" ]; then
		echo "/.nvmrc"
		return 0
	fi

	return 1
}

__load_nvm() {
	local selected_node

	if [ "$__NVM_LOADED" = "1" ] && whence -w nvm >/dev/null 2>&1; then
		selected_node="$(nvm which current 2>/dev/null)" || return 1
		__set_single_nvm_bin_on_path "$selected_node"
		return 0
	fi

	unset __NVM_LOADED
	unfunction nvm node npm npx yarn pnpm corepack 2>/dev/null

	if [ -s "$NVM_DIR/nvm.sh" ]; then
		source "$NVM_DIR/nvm.sh"
		[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
		__NVM_LOADED=1
		__ensure_nvm_default
		nvm use --silent default >/dev/null || return 1
		selected_node="$(nvm which default 2>/dev/null)" || return 1
		__set_single_nvm_bin_on_path "$selected_node"
		return 0
	fi

	return 1
}

__ensure_nvm_default() {
	local default_version
	default_version="$(nvm version default 2>/dev/null)"

	if [ "$default_version" = "N/A" ] || [[ "$default_version" != v${NVM_DEFAULT_VERSION}* ]]; then
		nvm install "$NVM_DEFAULT_VERSION" >/dev/null
		nvm alias default "$NVM_DEFAULT_VERSION" >/dev/null
	fi
}

# Load nvm once during shell startup. Lazy wrapper recursion can leave `nvm`
# pointing at itself and break unrelated aliases such as `gss`.
__load_nvm >/dev/null

loadNvmrc() {
	local nvmrc_path
	nvmrc_path="$(__find_nvmrc_upwards "$PWD")"

	if [ -n "$nvmrc_path" ]; then
		__load_nvm || return $?

		local nvmrc_node_version
		nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

		if [ "$nvmrc_node_version" = "N/A" ]; then
			nvm install
		elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
			nvm use
		fi
	elif [ -n "$__NVM_LOADED" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
		if [ -n "$(__find_nvmrc_upwards "$OLDPWD")" ]; then
			echo "Reverting to nvm default version"
		fi
		nvm use default
	fi
}

# Run pi using its installed Node version regardless of active .nvmrc.
# pi is a global npm install under the default NVM Node; nvm use changes PATH
# and hides that bin dir. This wrapper resolves the correct node + pi binary
# explicitly so repo Node version is unaffected.
pi() {
	local pi_node pi_node_bin

	__load_nvm || {
		echo "pi: NVM unavailable at $NVM_DIR." >&2
		return 127
	}

	pi_node="$(nvm which default 2>/dev/null)" || {
		echo "pi: default NVM Node unavailable." >&2
		echo "    Run: dotfiles npm" >&2
		return 127
	}
	pi_node_bin="${pi_node:h}"

	if [[ ! -x "$pi_node_bin/pi" ]]; then
		echo "pi: not installed under default Node $(nvm version default)." >&2
		echo "    Run: dotfiles npm" >&2
		return 127
	fi

	PATH="$pi_node_bin:$PATH" "$pi_node" "$pi_node_bin/pi" "$@"
}
