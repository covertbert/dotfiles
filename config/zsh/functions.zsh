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

_fnm_auto_use() {
	fnm use --install-if-missing --silent-if-unchanged
}

# Run Pi under fnm's default Node regardless of active project version.
pi() {
	if ! command -v fnm >/dev/null 2>&1; then
		echo "pi: fnm unavailable. Run: dotfiles brew" >&2
		return 127
	fi

	command fnm exec --using=default pi "$@"
}
