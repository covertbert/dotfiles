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
# Before interactive runs, update Pi and unpinned packages at most once per day.
pi() {
	if ! command -v fnm >/dev/null 2>&1; then
		echo "pi: fnm unavailable. Run: dotfiles brew" >&2
		return 127
	fi

	local -i auto_update=1
	local arg

	if [[ ! -t 0 || ! -t 1 || -n "${PI_OFFLINE:-}" || -n "${PI_SKIP_VERSION_CHECK:-}" ]]; then
		auto_update=0
	fi

	case "${1:-}" in
	install | remove | uninstall | update | list | config | -h | --help | -v | --version)
		auto_update=0
		;;
	esac

	for arg in "$@"; do
		case "$arg" in
		-p | --print | --mode | --export | --list-models | --offline)
			auto_update=0
			break
			;;
		esac
	done

	if ((auto_update)); then
		local update_stamp="${XDG_CACHE_HOME:-$HOME/.cache}/pi/last-auto-update"
		local -A update_stat
		local -i last_update=0

		zmodload zsh/datetime
		zmodload zsh/stat
		if zstat -H update_stat "$update_stamp" 2>/dev/null; then
			last_update=$update_stat[mtime]
		fi

		if ((EPOCHSECONDS - last_update >= 86400)); then
			command mkdir -p "${update_stamp:h}"
			command touch "$update_stamp"
			if ! command fnm exec --using=default pi update --all; then
				print -u2 "pi: auto-update failed; starting installed version. Retry: pi update --all"
			fi
		fi
	fi

	command fnm exec --using=default pi "$@"
}
