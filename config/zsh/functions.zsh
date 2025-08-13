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

loadNvmrc() {
	local nvmrc_path
	nvmrc_path="$(nvm_find_nvmrc)"

	if [ -n "$nvmrc_path" ]; then
		local nvmrc_node_version
		nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

		if [ "$nvmrc_node_version" = "N/A" ]; then
			nvm install
		elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
			nvm use
		fi
	elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
		echo "Reverting to nvm default version"
		nvm use default
	fi
}
