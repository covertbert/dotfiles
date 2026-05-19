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
	[ -n "$__NVM_LOADED" ] && return 0

	unset -f nvm node npm npx yarn pnpm corepack 2>/dev/null

	if [ -s "$NVM_DIR/nvm.sh" ]; then
		source "$NVM_DIR/nvm.sh"
		[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
		export __NVM_LOADED=1
		return 0
	fi

	return 1
}

nvm() {
	__load_nvm && nvm "$@"
}

__lazy_nvm_command() {
	local command_name="$1"
	shift

	if __load_nvm; then
		loadNvmrc
	fi

	command "$command_name" "$@"
}

node() { __lazy_nvm_command node "$@"; }
npm() { __lazy_nvm_command npm "$@"; }
npx() { __lazy_nvm_command npx "$@"; }
yarn() { __lazy_nvm_command yarn "$@"; }
pnpm() { __lazy_nvm_command pnpm "$@"; }
corepack() { __lazy_nvm_command corepack "$@"; }

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
	elif [ -n "$__NVM_LOADED" ] && [ -n "$(__find_nvmrc_upwards "$OLDPWD")" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
		echo "Reverting to nvm default version"
		nvm use default
	fi
}
