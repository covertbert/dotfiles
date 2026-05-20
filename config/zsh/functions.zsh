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

# Make globally installed commands from the default Node version (e.g. `pi`)
# available before nvm is lazy-loaded.
__add_nvm_default_bin_to_path() {
	local node_bin

	for node_bin in "$NVM_DIR"/versions/node/v"$NVM_DEFAULT_VERSION".*/bin(Nn); do
		path=("$node_bin" ${path:#$node_bin})
	done
}

__add_nvm_default_bin_to_path

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
	if [ "$__NVM_LOADED" = "1" ] && whence -w nvm >/dev/null 2>&1; then
		return 0
	fi

	unset __NVM_LOADED
	unfunction nvm node npm npx yarn pnpm corepack 2>/dev/null

	if [ -s "$NVM_DIR/nvm.sh" ]; then
		source "$NVM_DIR/nvm.sh"
		[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
		__NVM_LOADED=1
		__ensure_nvm_default
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
