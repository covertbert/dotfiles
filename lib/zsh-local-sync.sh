#!/usr/bin/env bash
# Interactive backup and restore for ~/.zshrc.local using a 1Password Document.
# This file is sourced by bin/dotfiles.
# shellcheck disable=SC2016 # jq and ZSH snippets need literal dollar expressions.

zsh_local_init() {
	ZSH_LOCAL_SYNC_FILE="${ZSH_LOCAL_SYNC_FILE:-$HOME/.zshrc.local}"
	ZSH_LOCAL_SYNC_STATE_DIR="${ZSH_LOCAL_SYNC_STATE_DIR:-$HOME/.local/state/dotfiles/zsh-local}"
	ZSH_LOCAL_SYNC_DEFAULT_VAULT="${ZSH_LOCAL_SYNC_DEFAULT_VAULT:-Private}"
	ZSH_LOCAL_SYNC_DEFAULT_DOCUMENT="${ZSH_LOCAL_SYNC_DEFAULT_DOCUMENT:-dotfiles: .zshrc.local}"
	ZSH_LOCAL_SYNC_OP_BIN="${ZSH_LOCAL_SYNC_OP_BIN:-op}"
	ZSH_LOCAL_SYNC_JQ_BIN="${ZSH_LOCAL_SYNC_JQ_BIN:-jq}"
	ZSH_LOCAL_SYNC_ZSH_BIN="${ZSH_LOCAL_SYNC_ZSH_BIN:-/bin/zsh}"
	ZSH_LOCAL_SYNC_SHASUM_BIN="${ZSH_LOCAL_SYNC_SHASUM_BIN:-shasum}"
	ZSH_LOCAL_SYNC_CONFIG_FILE="${ZSH_LOCAL_SYNC_STATE_DIR}/config.json"
	ZSH_LOCAL_SYNC_HASH_FILE="${ZSH_LOCAL_SYNC_STATE_DIR}/last-hash"
	ZSH_LOCAL_SYNC_LOCK_DIR="${ZSH_LOCAL_SYNC_STATE_DIR}/lock"

	ZSH_LOCAL_ITEM_ID=""
	ZSH_LOCAL_VAULT_ID=""
	ZSH_LOCAL_TEMP_FILES=("")
}

zsh_local_require_command() {
	local command_name="$1"

	if ! command -v "$command_name" &>/dev/null; then
		err "Missing dependency: ${command_name}"
		return 1
	fi
}

zsh_local_require_dependencies() {
	zsh_local_require_command "$ZSH_LOCAL_SYNC_OP_BIN" || return 1
	zsh_local_require_command "$ZSH_LOCAL_SYNC_JQ_BIN" || return 1
	zsh_local_require_command "$ZSH_LOCAL_SYNC_ZSH_BIN" || return 1
	zsh_local_require_command "$ZSH_LOCAL_SYNC_SHASUM_BIN" || return 1
}

zsh_local_prepare_state_dir() {
	mkdir -p "$ZSH_LOCAL_SYNC_STATE_DIR"
	chmod 700 "$ZSH_LOCAL_SYNC_STATE_DIR"
}

zsh_local_acquire_lock() {
	zsh_local_prepare_state_dir || return 1

	if mkdir "$ZSH_LOCAL_SYNC_LOCK_DIR" 2>/dev/null; then
		printf '%s\n' "$$" >"${ZSH_LOCAL_SYNC_LOCK_DIR}/pid"
		return 0
	fi

	local lock_pid=""
	if [[ -f "${ZSH_LOCAL_SYNC_LOCK_DIR}/pid" ]]; then
		IFS= read -r lock_pid <"${ZSH_LOCAL_SYNC_LOCK_DIR}/pid" || true
	fi

	if [[ "$lock_pid" =~ ^[0-9]+$ ]] && kill -0 "$lock_pid" 2>/dev/null; then
		err "Another zsh-local operation is running (PID ${lock_pid})."
		return 1
	fi

	rm -f "${ZSH_LOCAL_SYNC_LOCK_DIR}/pid"
	if ! rmdir "$ZSH_LOCAL_SYNC_LOCK_DIR" 2>/dev/null || ! mkdir "$ZSH_LOCAL_SYNC_LOCK_DIR" 2>/dev/null; then
		err "Could not acquire zsh-local lock: ${ZSH_LOCAL_SYNC_LOCK_DIR}"
		return 1
	fi

	printf '%s\n' "$$" >"${ZSH_LOCAL_SYNC_LOCK_DIR}/pid"
}

zsh_local_release_lock() {
	local temp_file

	for temp_file in "${ZSH_LOCAL_TEMP_FILES[@]}"; do
		[[ -n "$temp_file" ]] && rm -f "$temp_file" 2>/dev/null || true
	done
	ZSH_LOCAL_TEMP_FILES=("")

	rm -f "${ZSH_LOCAL_SYNC_LOCK_DIR}/pid" 2>/dev/null || true
	rmdir "$ZSH_LOCAL_SYNC_LOCK_DIR" 2>/dev/null || true
}

zsh_local_hash_file() {
	local file="$1"
	local output

	output="$("$ZSH_LOCAL_SYNC_SHASUM_BIN" -a 256 "$file")" || return 1
	printf '%s\n' "${output%% *}"
}

zsh_local_validate_file() {
	local file="$1"

	if [[ ! -f "$file" ]]; then
		err "Local zsh config missing: ${file}"
		return 1
	fi

	if ! "$ZSH_LOCAL_SYNC_ZSH_BIN" -n "$file" &>/dev/null; then
		err "ZSH syntax validation failed: ${file}"
		return 1
	fi
}

zsh_local_refuse_symlink() {
	if [[ -L "$ZSH_LOCAL_SYNC_FILE" ]]; then
		err "Refusing symlinked local config: ${ZSH_LOCAL_SYNC_FILE}"
		return 1
	fi
}

zsh_local_save_config() {
	local item_id="$1" vault_id="$2" document_title="$3" vault_name="$4"
	local tmp

	zsh_local_prepare_state_dir || return 1
	tmp="$(mktemp "${ZSH_LOCAL_SYNC_STATE_DIR}/.config.json.XXXXXX")" || return 1
	chmod 600 "$tmp"

	if ! "$ZSH_LOCAL_SYNC_JQ_BIN" -n \
		--arg itemId "$item_id" \
		--arg vaultId "$vault_id" \
		--arg documentTitle "$document_title" \
		--arg vaultName "$vault_name" \
		'{itemId: $itemId, vaultId: $vaultId, documentTitle: $documentTitle, vaultName: $vaultName}' >"$tmp"; then
		rm -f "$tmp"
		return 1
	fi

	mv -f "$tmp" "$ZSH_LOCAL_SYNC_CONFIG_FILE"
	chmod 600 "$ZSH_LOCAL_SYNC_CONFIG_FILE"
}

zsh_local_save_hash() {
	local hash="$1"
	local tmp

	zsh_local_prepare_state_dir || return 1
	tmp="$(mktemp "${ZSH_LOCAL_SYNC_STATE_DIR}/.last-hash.XXXXXX")" || return 1
	printf '%s\n' "$hash" >"$tmp"
	chmod 600 "$tmp"
	mv -f "$tmp" "$ZSH_LOCAL_SYNC_HASH_FILE"
}

zsh_local_read_hash() {
	local hash=""

	if [[ -f "$ZSH_LOCAL_SYNC_HASH_FILE" ]]; then
		IFS= read -r hash <"$ZSH_LOCAL_SYNC_HASH_FILE" || true
	fi

	if [[ "$hash" =~ ^[[:xdigit:]]{64}$ ]]; then
		printf '%s\n' "$hash"
	fi
}

zsh_local_load_config() {
	if [[ ! -f "$ZSH_LOCAL_SYNC_CONFIG_FILE" ]]; then
		err "zsh-local sync not configured. Run: dotfiles zsh-local setup"
		return 1
	fi

	if ! ZSH_LOCAL_ITEM_ID="$("$ZSH_LOCAL_SYNC_JQ_BIN" -er '.itemId | strings | select(length > 0)' "$ZSH_LOCAL_SYNC_CONFIG_FILE" 2>/dev/null)" ||
		! ZSH_LOCAL_VAULT_ID="$("$ZSH_LOCAL_SYNC_JQ_BIN" -er '.vaultId | strings | select(length > 0)' "$ZSH_LOCAL_SYNC_CONFIG_FILE" 2>/dev/null)"; then
		err "Invalid zsh-local state: ${ZSH_LOCAL_SYNC_CONFIG_FILE}"
		return 1
	fi
}

zsh_local_temp_file() {
	local __result_var="$1"
	local local_dir local_name temp_file
	local_dir="$(dirname "$ZSH_LOCAL_SYNC_FILE")"
	local_name="$(basename "$ZSH_LOCAL_SYNC_FILE")"
	temp_file="$(mktemp "${local_dir}/.${local_name}.1password.XXXXXX")" || return 1
	ZSH_LOCAL_TEMP_FILES+=("$temp_file")
	printf -v "$__result_var" '%s' "$temp_file"
}

zsh_local_download() {
	local destination="$1"

	: >"$destination"
	chmod 600 "$destination"
	if ! "$ZSH_LOCAL_SYNC_OP_BIN" document get "$ZSH_LOCAL_ITEM_ID" \
		--vault "$ZSH_LOCAL_VAULT_ID" \
		--out-file "$destination" \
		--file-mode 0600 \
		--force >/dev/null; then
		rm -f "$destination"
		err "Could not download zsh config from 1Password."
		return 1
	fi
}

zsh_local_install_download() {
	local source="$1"

	mv -f "$source" "$ZSH_LOCAL_SYNC_FILE"
	chmod 600 "$ZSH_LOCAL_SYNC_FILE"
}

zsh_local_prompt_initial_source() {
	local choice=""

	while true; do
		echo -en "  ${YELLOW}Use which copy?${RESET} ${BOLD}l${RESET}=local→1Password  ${BOLD}r${RESET}=1Password→local  ${BOLD}q${RESET}=quit: " >/dev/tty
		read_user_key choice || {
			echo "" >/dev/tty
			err "Could not read input. Aborting."
			return 1
		}
		case "$choice" in
		l | L)
			echo "local→1Password" >/dev/tty
			printf '%s\n' "local"
			return 0
			;;
		r | R)
			echo "1Password→local" >/dev/tty
			printf '%s\n' "1password"
			return 0
			;;
		q | Q)
			echo "quit" >/dev/tty
			return 1
			;;
		*)
			echo "" >/dev/tty
			;;
		esac
	done
}

zsh_local_setup() {
	shift # --yes is irrelevant until a direction is explicitly forced.
	local vault="$ZSH_LOCAL_SYNC_DEFAULT_VAULT"
	local document_title="$ZSH_LOCAL_SYNC_DEFAULT_DOCUMENT"
	local source_choice=""
	local items_json match_count item_id vault_id created_json local_hash remote_hash tmp

	while (($# > 0)); do
		case "$1" in
		--vault)
			[[ $# -ge 2 ]] || {
				err "--vault requires a value."
				return 1
			}
			vault="$2"
			shift 2
			;;
		--document)
			[[ $# -ge 2 ]] || {
				err "--document requires a value."
				return 1
			}
			document_title="$2"
			shift 2
			;;
		--use-local)
			if [[ -n "$source_choice" && "$source_choice" != "local" ]]; then
				err "Choose only one initial source."
				return 1
			fi
			source_choice="local"
			shift
			;;
		--use-1password)
			if [[ -n "$source_choice" && "$source_choice" != "1password" ]]; then
				err "Choose only one initial source."
				return 1
			fi
			source_choice="1password"
			shift
			;;
		*)
			err "Unknown zsh-local setup option: $1"
			return 1
			;;
		esac
	done

	if [[ "$source_choice" == "local" && ! -f "$ZSH_LOCAL_SYNC_FILE" ]]; then
		err "Cannot use missing local config: ${ZSH_LOCAL_SYNC_FILE}"
		return 1
	fi

	zsh_local_refuse_symlink || return 1
	info "Looking for 1Password Document '${document_title}' in vault '${vault}'..."
	if ! items_json="$("$ZSH_LOCAL_SYNC_OP_BIN" item list \
		--categories Document \
		--vault "$vault" \
		--format=json)"; then
		err "Could not list 1Password Documents."
		return 1
	fi

	if ! match_count="$(printf '%s' "$items_json" | "$ZSH_LOCAL_SYNC_JQ_BIN" -er \
		--arg title "$document_title" \
		'[.[] | select(.title == $title)] | length')"; then
		err "Could not parse 1Password response."
		return 1
	fi

	if ((match_count > 1)); then
		err "Multiple Documents named '${document_title}' found in '${vault}'."
		err "Rename duplicates or choose another title with --document."
		return 1
	fi

	if ((match_count == 0)); then
		if [[ "$source_choice" == "1password" ]]; then
			err "Cannot use 1Password source: matching Document does not exist."
			return 1
		fi
		if [[ ! -f "$ZSH_LOCAL_SYNC_FILE" ]]; then
			err "No local config and no matching 1Password Document."
			return 1
		fi
		zsh_local_validate_file "$ZSH_LOCAL_SYNC_FILE" || return 1
		chmod 600 "$ZSH_LOCAL_SYNC_FILE"

		info "Creating 1Password Document..."
		if ! created_json="$("$ZSH_LOCAL_SYNC_OP_BIN" document create "$ZSH_LOCAL_SYNC_FILE" \
			--title "$document_title" \
			--file-name ".zshrc.local" \
			--vault "$vault" \
			--format=json)"; then
			err "Could not create 1Password Document."
			return 1
		fi

		if ! item_id="$(printf '%s' "$created_json" | "$ZSH_LOCAL_SYNC_JQ_BIN" -er '.id | strings | select(length > 0)')"; then
			err "Document created, but 1Password returned no item ID. Run setup again."
			return 1
		fi
		vault_id="$(printf '%s' "$created_json" | "$ZSH_LOCAL_SYNC_JQ_BIN" -r '.vault.id // empty')"
		[[ -n "$vault_id" ]] || vault_id="$vault"
		local_hash="$(zsh_local_hash_file "$ZSH_LOCAL_SYNC_FILE")" || return 1
		zsh_local_save_config "$item_id" "$vault_id" "$document_title" "$vault" || return 1
		zsh_local_save_hash "$local_hash" || return 1
		ok "Created 1Password backup for ${ZSH_LOCAL_SYNC_FILE}."
		return 0
	fi

	item_id="$(printf '%s' "$items_json" | "$ZSH_LOCAL_SYNC_JQ_BIN" -er \
		--arg title "$document_title" \
		'.[] | select(.title == $title) | .id')" || return 1
	vault_id="$(printf '%s' "$items_json" | "$ZSH_LOCAL_SYNC_JQ_BIN" -r \
		--arg title "$document_title" \
		'.[] | select(.title == $title) | .vault.id // empty')"
	[[ -n "$vault_id" ]] || vault_id="$vault"

	ZSH_LOCAL_ITEM_ID="$item_id"
	ZSH_LOCAL_VAULT_ID="$vault_id"

	zsh_local_temp_file tmp || return 1
	if ! zsh_local_download "$tmp"; then
		return 1
	fi
	if ! zsh_local_validate_file "$tmp"; then
		rm -f "$tmp"
		err "1Password Document is not valid ZSH; local file unchanged."
		return 1
	fi
	remote_hash="$(zsh_local_hash_file "$tmp")" || {
		rm -f "$tmp"
		return 1
	}

	if [[ ! -f "$ZSH_LOCAL_SYNC_FILE" ]]; then
		zsh_local_install_download "$tmp" || return 1
		zsh_local_save_config "$item_id" "$vault_id" "$document_title" "$vault" || return 1
		zsh_local_save_hash "$remote_hash" || return 1
		ok "Restored ${ZSH_LOCAL_SYNC_FILE} from 1Password."
		return 0
	fi

	local_hash="$(zsh_local_hash_file "$ZSH_LOCAL_SYNC_FILE")" || {
		rm -f "$tmp"
		return 1
	}
	if [[ "$local_hash" == "$remote_hash" ]]; then
		rm -f "$tmp"
		chmod 600 "$ZSH_LOCAL_SYNC_FILE"
		zsh_local_save_config "$item_id" "$vault_id" "$document_title" "$vault" || return 1
		zsh_local_save_hash "$local_hash" || return 1
		ok "Local config already matches 1Password."
		return 0
	fi

	warn "Local config and 1Password Document differ. Contents will not be displayed."
	if [[ -z "$source_choice" ]]; then
		if ! source_choice="$(zsh_local_prompt_initial_source)"; then
			rm -f "$tmp"
			echo "Aborted."
			return 1
		fi
	fi

	case "$source_choice" in
	local)
		rm -f "$tmp"
		zsh_local_validate_file "$ZSH_LOCAL_SYNC_FILE" || return 1
		chmod 600 "$ZSH_LOCAL_SYNC_FILE"
		if ! "$ZSH_LOCAL_SYNC_OP_BIN" document edit "$item_id" "$ZSH_LOCAL_SYNC_FILE" --vault "$vault_id" >/dev/null; then
			err "Could not update 1Password Document."
			return 1
		fi
		zsh_local_save_config "$item_id" "$vault_id" "$document_title" "$vault" || return 1
		zsh_local_save_hash "$local_hash" || return 1
		ok "Uploaded local config to 1Password."
		;;
	1password)
		zsh_local_install_download "$tmp" || return 1
		zsh_local_save_config "$item_id" "$vault_id" "$document_title" "$vault" || return 1
		zsh_local_save_hash "$remote_hash" || return 1
		ok "Restored local config from 1Password."
		;;
	*)
		rm -f "$tmp"
		err "Choose only one initial source: --use-local or --use-1password."
		return 1
		;;
	esac
}

zsh_local_status() {
	local tmp local_hash remote_hash last_hash

	zsh_local_load_config || return 1
	zsh_local_refuse_symlink || return 1
	zsh_local_temp_file tmp || return 1
	if ! zsh_local_download "$tmp"; then
		return 1
	fi
	remote_hash="$(zsh_local_hash_file "$tmp")" || {
		rm -f "$tmp"
		return 1
	}
	if ! zsh_local_validate_file "$tmp"; then
		rm -f "$tmp"
		err "1Password Document is not valid ZSH."
		return 1
	fi
	rm -f "$tmp"

	if [[ ! -f "$ZSH_LOCAL_SYNC_FILE" ]]; then
		warn "Local config missing. Run: dotfiles zsh-local pull"
		return 0
	fi

	local_hash="$(zsh_local_hash_file "$ZSH_LOCAL_SYNC_FILE")" || return 1
	last_hash="$(zsh_local_read_hash)"

	if [[ "$local_hash" == "$remote_hash" ]]; then
		zsh_local_save_hash "$local_hash" || return 1
		ok "Local config and 1Password Document are in sync."
	elif [[ -z "$last_hash" ]]; then
		warn "Copies differ and no sync baseline exists. Run setup or use explicit --force."
	elif [[ "$remote_hash" == "$last_hash" ]]; then
		warn "Local config changed. Run: dotfiles zsh-local push"
	elif [[ "$local_hash" == "$last_hash" ]]; then
		warn "1Password Document changed. Run: dotfiles zsh-local pull"
	else
		warn "Conflict: local config and 1Password Document both changed."
	fi
}

zsh_local_push() {
	local yes_flag="$1" force="$2"
	local tmp local_hash remote_hash last_hash

	zsh_local_load_config || return 1
	zsh_local_refuse_symlink || return 1
	zsh_local_validate_file "$ZSH_LOCAL_SYNC_FILE" || return 1
	chmod 600 "$ZSH_LOCAL_SYNC_FILE"
	local_hash="$(zsh_local_hash_file "$ZSH_LOCAL_SYNC_FILE")" || return 1

	zsh_local_temp_file tmp || return 1
	if ! zsh_local_download "$tmp"; then
		return 1
	fi
	remote_hash="$(zsh_local_hash_file "$tmp")" || {
		rm -f "$tmp"
		return 1
	}
	rm -f "$tmp"

	if [[ "$local_hash" == "$remote_hash" ]]; then
		zsh_local_save_hash "$local_hash" || return 1
		ok "Nothing to upload; copies already match."
		return 0
	fi

	last_hash="$(zsh_local_read_hash)"
	if [[ -z "$last_hash" || "$remote_hash" != "$last_hash" ]]; then
		if [[ "$force" != true ]]; then
			err "1Password copy changed or no baseline exists; refusing overwrite."
			err "Inspect item in 1Password, then use push --force if local should win."
			return 1
		fi
		warn "This will replace changed 1Password content with local config."
		if [[ "$yes_flag" != "--yes" ]]; then
			confirm "Replace 1Password Document?" || {
				echo "Aborted."
				return 1
			}
		fi
	fi

	if ! "$ZSH_LOCAL_SYNC_OP_BIN" document edit "$ZSH_LOCAL_ITEM_ID" "$ZSH_LOCAL_SYNC_FILE" \
		--vault "$ZSH_LOCAL_VAULT_ID" >/dev/null; then
		err "Could not update 1Password Document."
		return 1
	fi

	zsh_local_save_hash "$local_hash" || return 1
	ok "Uploaded ${ZSH_LOCAL_SYNC_FILE} to 1Password."
}

zsh_local_pull() {
	local yes_flag="$1" force="$2"
	local tmp local_hash="" remote_hash last_hash

	zsh_local_load_config || return 1
	zsh_local_refuse_symlink || return 1
	zsh_local_temp_file tmp || return 1
	if ! zsh_local_download "$tmp"; then
		return 1
	fi
	if ! zsh_local_validate_file "$tmp"; then
		rm -f "$tmp"
		err "1Password Document is not valid ZSH; local file unchanged."
		return 1
	fi
	remote_hash="$(zsh_local_hash_file "$tmp")" || {
		rm -f "$tmp"
		return 1
	}

	if [[ -f "$ZSH_LOCAL_SYNC_FILE" ]]; then
		local_hash="$(zsh_local_hash_file "$ZSH_LOCAL_SYNC_FILE")" || {
			rm -f "$tmp"
			return 1
		}
		if [[ "$local_hash" == "$remote_hash" ]]; then
			rm -f "$tmp"
			chmod 600 "$ZSH_LOCAL_SYNC_FILE"
			zsh_local_save_hash "$local_hash" || return 1
			ok "Nothing to restore; copies already match."
			return 0
		fi

		last_hash="$(zsh_local_read_hash)"
		if [[ -z "$last_hash" || "$local_hash" != "$last_hash" ]]; then
			if [[ "$force" != true ]]; then
				rm -f "$tmp"
				err "Local config has unsynced changes or no baseline; refusing overwrite."
				err "Use pull --force if 1Password should win."
				return 1
			fi
			warn "This will replace changed local config with 1Password content."
		fi

		if [[ "$yes_flag" != "--yes" ]]; then
			confirm "Replace ${ZSH_LOCAL_SYNC_FILE}?" || {
				rm -f "$tmp"
				echo "Aborted."
				return 1
			}
		fi
	fi

	zsh_local_install_download "$tmp" || return 1
	zsh_local_save_hash "$remote_hash" || return 1
	ok "Restored ${ZSH_LOCAL_SYNC_FILE} from 1Password."
}

zsh_local_edit() {
	local yes_flag="$1"
	local tmp local_hash remote_hash last_hash editor

	zsh_local_load_config || return 1
	zsh_local_refuse_symlink || return 1

	if [[ ! -f "$ZSH_LOCAL_SYNC_FILE" ]]; then
		info "Local config missing; restoring from 1Password first."
		zsh_local_pull "--yes" false || return 1
	else
		zsh_local_temp_file tmp || return 1
		if ! zsh_local_download "$tmp"; then
			return 1
		fi
		if ! zsh_local_validate_file "$tmp"; then
			rm -f "$tmp"
			err "1Password Document is not valid ZSH; edit aborted."
			return 1
		fi
		remote_hash="$(zsh_local_hash_file "$tmp")" || {
			rm -f "$tmp"
			return 1
		}
		rm -f "$tmp"
		local_hash="$(zsh_local_hash_file "$ZSH_LOCAL_SYNC_FILE")" || return 1
		last_hash="$(zsh_local_read_hash)"

		if [[ "$local_hash" == "$remote_hash" ]]; then
			zsh_local_save_hash "$local_hash" || return 1
		elif [[ -z "$last_hash" ]]; then
			err "Copies differ and no sync baseline exists. Run: dotfiles zsh-local setup"
			return 1
		elif [[ "$remote_hash" != "$last_hash" ]]; then
			err "1Password Document changed; refusing to start an edit from stale local content."
			err "Run: dotfiles zsh-local pull"
			return 1
		fi
	fi

	editor="${VISUAL:-${EDITOR:-vi}}"
	info "Opening ${ZSH_LOCAL_SYNC_FILE} with ${editor}..."
	if ! ZSH_LOCAL_EDITOR_COMMAND="$editor" "$ZSH_LOCAL_SYNC_ZSH_BIN" -c '
editor=(${(z)ZSH_LOCAL_EDITOR_COMMAND})
(( ${#editor[@]} > 0 )) || exit 1
exec "${editor[@]}" "$1"
' zsh-local-edit "$ZSH_LOCAL_SYNC_FILE"; then
		err "Editor exited unsuccessfully; nothing uploaded."
		return 1
	fi

	zsh_local_validate_file "$ZSH_LOCAL_SYNC_FILE" || return 1
	zsh_local_push "$yes_flag" false
}

zsh_local_parse_force() {
	local __result_var="$1"
	shift
	local parsed_force=false

	while (($# > 0)); do
		case "$1" in
		--force)
			parsed_force=true
			;;
		*)
			err "Unknown zsh-local option: $1"
			return 1
			;;
		esac
		shift
	done

	printf -v "$__result_var" '%s' "$parsed_force"
}

zsh_local_usage() {
	cat <<EOF
${BOLD}dotfiles zsh-local${RESET} — back up ~/.zshrc.local to a 1Password Document

${BOLD}USAGE${RESET}
  dotfiles zsh-local <action> [options]

${BOLD}ACTIONS${RESET}
  setup                 Find or create the 1Password Document
  edit                  Check remote, open \$EDITOR, validate, and upload changes
  status                Compare local and 1Password copies without showing contents
  push                  Upload local changes
  pull                  Explicitly restore from 1Password

${BOLD}SETUP OPTIONS${RESET}
  --vault <vault>       Vault name or ID (default: Private)
  --document <title>    Document title (default: dotfiles: .zshrc.local)
  --use-local           Resolve initial mismatch using local content
  --use-1password       Resolve initial mismatch using 1Password content

${BOLD}WRITE OPTIONS${RESET}
  --force               Resolve a conflict in push/pull using requested direction
  --yes                 Skip requested overwrite confirmation
EOF
}

cmd_zsh_local() {
	local yes_flag="$1"
	shift
	local action="${1:-help}"
	shift || true
	local force=false status=0

	zsh_local_init
	umask 077

	case "$action" in
	help | --help | -h)
		zsh_local_usage
		return 0
		;;
	setup | edit | status | push | pull) ;;
	*)
		err "Unknown zsh-local action: ${action}"
		zsh_local_usage
		return 1
		;;
	esac

	zsh_local_require_dependencies || return 1
	zsh_local_acquire_lock || return 1
	trap zsh_local_release_lock EXIT
	trap 'zsh_local_release_lock; exit 130' INT TERM

	case "$action" in
	setup)
		zsh_local_setup "$yes_flag" "$@" || status=$?
		;;
	edit)
		if (($# > 0)); then
			err "zsh-local edit takes no options."
			status=1
		else
			zsh_local_edit "$yes_flag" || status=$?
		fi
		;;
	status)
		if (($# > 0)); then
			err "zsh-local status takes no options."
			status=1
		else
			zsh_local_status || status=$?
		fi
		;;
	push)
		if zsh_local_parse_force force "$@"; then
			zsh_local_push "$yes_flag" "$force" || status=$?
		else
			status=$?
		fi
		;;
	pull)
		if zsh_local_parse_force force "$@"; then
			zsh_local_pull "$yes_flag" "$force" || status=$?
		else
			status=$?
		fi
		;;
	esac

	trap - EXIT INT TERM
	zsh_local_release_lock
	return "$status"
}
