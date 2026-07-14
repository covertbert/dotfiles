#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_BIN="${ROOT_DIR}/bin/dotfiles"
TEST_ROOT="$(mktemp -d)"
MOCK_BIN="${TEST_ROOT}/bin"
PASS_COUNT=0

cleanup() {
	rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$MOCK_BIN"

cat >"${MOCK_BIN}/op" <<'MOCK_OP'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$MOCK_OP_LOG"

command_group="${1:-}"
action="${2:-}"
shift 2 || true

case "${command_group} ${action}" in
"item list")
	if [[ -f "${MOCK_REMOTE_DIR}/meta.json" ]]; then
		jq -c '[.]' "${MOCK_REMOTE_DIR}/meta.json"
	else
		printf '%s\n' '[]'
	fi
	;;
"document create")
	file="$1"
	shift
	title=""
	vault=""
	while (($# > 0)); do
		case "$1" in
		--title)
			title="$2"
			shift 2
			;;
		--vault)
			vault="$2"
			shift 2
			;;
		--file-name)
			shift 2
			;;
		--format=json)
			shift
			;;
		*)
			shift
			;;
		esac
	done
	mkdir -p "$MOCK_REMOTE_DIR"
	cp "$file" "${MOCK_REMOTE_DIR}/content"
	jq -n --arg id mock-item-id --arg title "$title" --arg vault "$vault" \
		'{id: $id, title: $title, vault: {id: $vault}}' >"${MOCK_REMOTE_DIR}/meta.json"
	jq -c . "${MOCK_REMOTE_DIR}/meta.json"
	;;
"document get")
	item_id="$1"
	shift
	out_file=""
	while (($# > 0)); do
		case "$1" in
		--out-file)
			out_file="$2"
			shift 2
			;;
		--vault | --file-mode)
			shift 2
			;;
		--force)
			shift
			;;
		*)
			shift
			;;
		esac
	done
	[[ "$item_id" == "mock-item-id" ]]
	[[ -n "$out_file" ]]
	if [[ "${MOCK_OP_FAIL_GET:-0}" == "1" ]]; then
		printf '%s\n' 'partial remote data' >"$out_file"
		exit 1
	fi
	cp "${MOCK_REMOTE_DIR}/content" "$out_file"
	;;
"document edit")
	item_id="$1"
	file="$2"
	[[ "$item_id" == "mock-item-id" ]]
	cp "$file" "${MOCK_REMOTE_DIR}/content"
	jq -c . "${MOCK_REMOTE_DIR}/meta.json"
	;;
*)
	printf 'Unexpected mock op command: %s %s\n' "$command_group" "$action" >&2
	exit 1
	;;
esac
MOCK_OP
chmod +x "${MOCK_BIN}/op"

cat >"${MOCK_BIN}/editor" <<'MOCK_EDITOR'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'export EDITED_BY_TEST=1' >>"$1"
MOCK_EDITOR
chmod +x "${MOCK_BIN}/editor"

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

pass() {
	PASS_COUNT=$((PASS_COUNT + 1))
	printf 'ok %d - %s\n' "$PASS_COUNT" "$1"
}

assert_files_equal() {
	local expected="$1" actual="$2" message="$3"
	cmp -s "$expected" "$actual" || fail "$message"
}

new_case() {
	local name="$1"
	CASE_DIR="${TEST_ROOT}/${name}"
	HOME="${CASE_DIR}/home"
	MOCK_REMOTE_DIR="${CASE_DIR}/remote"
	MOCK_OP_LOG="${CASE_DIR}/op.log"
	ZSH_LOCAL_SYNC_FILE="${HOME}/.zshrc.local"
	ZSH_LOCAL_SYNC_STATE_DIR="${HOME}/.local/state/dotfiles/zsh-local"
	ZSH_LOCAL_SYNC_OP_BIN="${MOCK_BIN}/op"
	VISUAL="${MOCK_BIN}/editor"
	EDITOR="${MOCK_BIN}/editor"
	export HOME MOCK_REMOTE_DIR MOCK_OP_LOG ZSH_LOCAL_SYNC_FILE ZSH_LOCAL_SYNC_STATE_DIR
	export ZSH_LOCAL_SYNC_OP_BIN VISUAL EDITOR
	unset MOCK_OP_FAIL_GET
	mkdir -p "$HOME" "$MOCK_REMOTE_DIR"
	: >"$MOCK_OP_LOG"
}

seed_remote() {
	local content="$1"
	printf '%s' "$content" >"${MOCK_REMOTE_DIR}/content"
	jq -n --arg id mock-item-id --arg title 'Test zsh local' --arg vault 'Test Vault' \
		'{id: $id, title: $title, vault: {id: $vault}}' >"${MOCK_REMOTE_DIR}/meta.json"
}

run_dotfiles() {
	"$DOTFILES_BIN" zsh-local "$@"
}

setup_from_local() {
	run_dotfiles setup --vault 'Test Vault' --document 'Test zsh local' --yes >/dev/null
}

# Create Document from local source.
new_case create
printf '%s\n' "export CREATED_SECRET='create-value'" >"$ZSH_LOCAL_SYNC_FILE"
setup_from_local
assert_files_equal "$ZSH_LOCAL_SYNC_FILE" "${MOCK_REMOTE_DIR}/content" "setup did not upload local file"
[[ -f "${ZSH_LOCAL_SYNC_STATE_DIR}/config.json" ]] || fail "setup did not save config"
[[ "$(stat -f '%Lp' "$ZSH_LOCAL_SYNC_FILE")" == "600" ]] || fail "local mode is not 0600"
pass "setup creates Document from local file"

# Restore missing local source from existing Document.
new_case restore
seed_remote $'export RESTORED_SECRET=1\n'
run_dotfiles setup --vault 'Test Vault' --document 'Test zsh local' --yes >/dev/null
assert_files_equal "${MOCK_REMOTE_DIR}/content" "$ZSH_LOCAL_SYNC_FILE" "setup did not restore missing local file"
[[ "$(stat -f '%Lp' "$ZSH_LOCAL_SYNC_FILE")" == "600" ]] || fail "restored mode is not 0600"
pass "setup restores missing local file"

# Initial mismatch requires an explicit source direction.
new_case initial-local
seed_remote $'export REMOTE_OLD=1\n'
printf '%s\n' 'export LOCAL_WINS=1' >"$ZSH_LOCAL_SYNC_FILE"
run_dotfiles setup --vault 'Test Vault' --document 'Test zsh local' --use-local --yes >/dev/null
assert_files_equal "$ZSH_LOCAL_SYNC_FILE" "${MOCK_REMOTE_DIR}/content" "--use-local did not replace remote"
pass "setup can resolve initial mismatch using local source"

new_case initial-remote
seed_remote $'export REMOTE_WINS=1\n'
printf '%s\n' 'export LOCAL_OLD=1' >"$ZSH_LOCAL_SYNC_FILE"
run_dotfiles setup --vault 'Test Vault' --document 'Test zsh local' --use-1password --yes >/dev/null
assert_files_equal "${MOCK_REMOTE_DIR}/content" "$ZSH_LOCAL_SYNC_FILE" "--use-1password did not replace local"
pass "setup can resolve initial mismatch using 1Password source"

# Edit command opens editor, validates, and uploads.
new_case edit
printf '%s\n' 'export BEFORE_EDIT=1' >"$ZSH_LOCAL_SYNC_FILE"
setup_from_local
run_dotfiles edit --yes >/dev/null
assert_files_equal "$ZSH_LOCAL_SYNC_FILE" "${MOCK_REMOTE_DIR}/content" "edit did not upload result"
grep -q 'EDITED_BY_TEST' "${MOCK_REMOTE_DIR}/content" || fail "editor result missing remotely"
pass "edit uploads validated editor result"

# Push refuses when remote changed since baseline.
new_case push-conflict
printf '%s\n' 'export BASE=1' >"$ZSH_LOCAL_SYNC_FILE"
setup_from_local
printf '%s\n' 'export LOCAL_CHANGE=1' >>"$ZSH_LOCAL_SYNC_FILE"
printf '%s\n' 'export REMOTE_CHANGE=1' >"${MOCK_REMOTE_DIR}/content"
cp "${MOCK_REMOTE_DIR}/content" "${CASE_DIR}/expected-remote"
if run_dotfiles push --yes >/dev/null 2>&1; then
	fail "push accepted changed remote without --force"
fi
assert_files_equal "${CASE_DIR}/expected-remote" "${MOCK_REMOTE_DIR}/content" "push conflict changed remote"
pass "push refuses remote conflict"

# Pull refuses unsynced local changes, then allows explicit forced restore.
new_case pull-conflict
printf '%s\n' 'export BASE=1' >"$ZSH_LOCAL_SYNC_FILE"
setup_from_local
printf '%s\n' 'export LOCAL_CHANGE=1' >>"$ZSH_LOCAL_SYNC_FILE"
printf '%s\n' 'export REMOTE_CHANGE=1' >"${MOCK_REMOTE_DIR}/content"
if run_dotfiles pull --yes >/dev/null 2>&1; then
	fail "pull accepted unsynced local content without --force"
fi
run_dotfiles pull --force --yes >/dev/null
assert_files_equal "${MOCK_REMOTE_DIR}/content" "$ZSH_LOCAL_SYNC_FILE" "forced pull did not restore remote"
pass "pull needs explicit force for local conflict"

# Invalid ZSH never reaches remote.
new_case invalid
printf '%s\n' 'export VALID=1' >"$ZSH_LOCAL_SYNC_FILE"
setup_from_local
cp "${MOCK_REMOTE_DIR}/content" "${CASE_DIR}/expected-remote"
printf '%s\n' 'if then' >"$ZSH_LOCAL_SYNC_FILE"
if run_dotfiles push --yes >/dev/null 2>&1; then
	fail "push accepted invalid ZSH"
fi
assert_files_equal "${CASE_DIR}/expected-remote" "${MOCK_REMOTE_DIR}/content" "invalid push changed remote"
pass "push rejects invalid ZSH"

# Failed download leaves local file untouched.
new_case atomic
printf '%s\n' 'export LOCAL_SAFE=1' >"$ZSH_LOCAL_SYNC_FILE"
setup_from_local
cp "$ZSH_LOCAL_SYNC_FILE" "${CASE_DIR}/expected-local"
printf '%s\n' 'export REMOTE_NEW=1' >"${MOCK_REMOTE_DIR}/content"
export MOCK_OP_FAIL_GET=1
if run_dotfiles pull --force --yes >/dev/null 2>&1; then
	fail "pull succeeded after failed download"
fi
unset MOCK_OP_FAIL_GET
assert_files_equal "${CASE_DIR}/expected-local" "$ZSH_LOCAL_SYNC_FILE" "failed pull changed local file"
[[ -z "$(find "$HOME" -maxdepth 1 -name '.*.1password.*' -print -quit)" ]] || fail "failed pull left a temporary secret file"
pass "failed download preserves local file and removes temporary data"

# Status and command output never expose file contents.
new_case no-leak
secret="DO_NOT_PRINT_$(date +%s)_VALUE"
printf "export OUTPUT_SECRET='%s'\n" "$secret" >"$ZSH_LOCAL_SYNC_FILE"
output="$(run_dotfiles setup --vault 'Test Vault' --document 'Test zsh local' --yes 2>&1)"
output+="$(run_dotfiles status 2>&1)"
[[ "$output" != *"$secret"* ]] || fail "secret appeared in command output"
pass "output does not expose config contents"

printf '1..%d\n' "$PASS_COUNT"
