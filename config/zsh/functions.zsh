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

# Fetch a GitLab API endpoint, keeping the API response separate from errors.
# Prints the response on success and the failure detail on stderr.
_gitlab_main_push_json() {
	local response
	if ! response=$(glab api "$@" 2>&1); then
		print -u2 "gitlab-main-push: GitLab request failed: glab api $*"
		print -u2 "$response"
		return 1
	fi
	print -r -- "$response"
}

# Add or remove the authenticated user from the explicit push allowlist of the
# current repository's `main` protection rule. Removing the entry does not
# guarantee pushes are blocked: matching roles, groups, or other rules can still
# grant access, so the command reports allowlist membership, not effective
# permission. Requires GitLab Premium or Ultimate, an account allowed to edit
# the rule, and a project on the GitLab host configured for this repository.
# `gitlab-main-push status` reports membership without changing anything.
gitlab-main-push() {
	local action="${1:-toggle}"
	local project_json user_json branch_json ids payload response
	local project_id project_path user_id login ids_text want dep

	case "$action" in
	status | toggle) ;;
	*)
		print -u2 "usage: gitlab-main-push [status]"
		return 2
		;;
	esac

	for dep in glab jq git; do
		if ! command -v "$dep" >/dev/null 2>&1; then
			print -u2 "gitlab-main-push: required command not found: $dep"
			return 127
		fi
	done

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		print -u2 "gitlab-main-push: not inside a Git repository"
		return 1
	fi

	project_json=$(_gitlab_main_push_json projects/:id) || return 1
	project_id=$(jq -er '.id | select(type == "number")' <<<"$project_json" 2>/dev/null) || {
		print -u2 "gitlab-main-push: unexpected project response"
		return 1
	}
	project_path=$(jq -r '.path_with_namespace // "unknown project"' <<<"$project_json")

	user_json=$(_gitlab_main_push_json user) || return 1
	user_id=$(jq -er '.id | select(type == "number")' <<<"$user_json" 2>/dev/null) || {
		print -u2 "gitlab-main-push: unexpected user response"
		return 1
	}
	login=$(jq -r '.username // "unknown user"' <<<"$user_json")

	branch_json=$(_gitlab_main_push_json "projects/${project_id}/protected_branches/main") || {
		print -u2 "gitlab-main-push: cannot read the protected branch 'main' for ${project_path}"
		return 1
	}
	if ! jq -e '.push_access_levels | type == "array"' >/dev/null 2>&1 <<<"$branch_json"; then
		print -u2 "gitlab-main-push: unexpected protected branch response"
		return 1
	fi
	if [[ "$(jq -r '.inherited // false' <<<"$branch_json")" == true ]]; then
		print -u2 "gitlab-main-push: protection for 'main' is inherited from a parent group; change it there"
		return 1
	fi

	ids=$(jq -c --argjson uid "$user_id" \
		'[.push_access_levels[] | select(.user_id == $uid) | .id]' <<<"$branch_json") || {
		print -u2 "gitlab-main-push: unexpected push access levels"
		return 1
	}
	ids_text=$(jq -r 'join(", ")' <<<"$ids")

	if [[ "$action" == status ]]; then
		if [[ "$ids" == "[]" ]]; then
			print -r -- "${project_path} main: ${login} is not in the explicit push allowlist"
		else
			print -r -- "${project_path} main: ${login} is in the explicit push allowlist (ids: ${ids_text})"
		fi
		return 0
	fi

	if [[ "$ids" == "[]" ]]; then
		want=true
	else
		want=false
	fi

	# Incremental access-level entries: no `id` creates an entry, `_destroy`
	# removes one, and untouched entries are left alone. The API replaces nothing.
	payload=$(jq -cn --argjson ids "$ids" --argjson uid "$user_id" '
		if ($ids | length) > 0 then
			{allowed_to_push: ($ids | map({id: ., _destroy: true}))}
		else
			{allowed_to_push: [{user_id: $uid}]}
		end') || {
		print -u2 "gitlab-main-push: failed to build update payload"
		return 1
	}

	if ! response=$(print -r -- "$payload" | glab api --method PATCH \
		"projects/${project_id}/protected_branches/main" \
		--header 'Content-Type: application/json' --input - 2>&1); then
		print -u2 "gitlab-main-push: update of ${project_path} main failed"
		print -u2 "$response"
		return 1
	fi

	if ! jq -e --argjson uid "$user_id" --argjson want "$want" \
		'[.push_access_levels[] | select(.user_id == $uid)] | (length > 0) == $want' \
		>/dev/null 2>&1 <<<"$response"; then
		print -u2 "gitlab-main-push: GitLab did not apply the expected change; run 'gitlab-main-push status' to inspect"
		print -u2 "$response"
		return 1
	fi

	if [[ "$want" == true ]]; then
		print -r -- "${project_path} main: added ${login} to the explicit push allowlist"
	else
		print -r -- "${project_path} main: removed ${login} from the explicit push allowlist"
		print -r -- "note: pushes to 'main' may still be allowed by roles, groups, or other rules"
	fi
}
