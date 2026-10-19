#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSH_FUNCTIONS="${ROOT_DIR}/config/zsh/functions.zsh"
TEST_ROOT="$(mktemp -d)"
MOCK_BIN="${TEST_ROOT}/bin"
PASS_COUNT=0

cleanup() {
	rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$MOCK_BIN"

cat >"${MOCK_BIN}/glab" <<'MOCK_GLAB'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$MOCK_GLAB_LOG"

apply_patch() {
	if [[ "${MOCK_FAIL_PATCH:-0}" == "1" ]]; then
		printf 'patch rejected\n' >&2
		exit 1
	fi
	cp "$MOCK_STATE/payload.json" "$MOCK_STATE/last-payload.json"
	local destroy adds
	destroy=$(jq -c '[.allowed_to_push[] | select(._destroy) | .id]' "$MOCK_STATE/payload.json")
	adds=$(jq -c '[.allowed_to_push[] | select(has("user_id")) | .user_id]' "$MOCK_STATE/payload.json")
	jq --argjson destroy "$destroy" --argjson adds "$adds" '
		.push_access_levels |= (
			map(select(.id as $id | ($destroy | index($id)) == null))
			+ ($adds | map({id: (1000 + .), access_level: null, user_id: ., group_id: null}))
		)' "$MOCK_STATE/branch.json" >"$MOCK_STATE/branch.next"
	mv "$MOCK_STATE/branch.next" "$MOCK_STATE/branch.json"
}

[[ "${1:-}" == "api" ]] || { printf 'Unexpected glab command: %s\n' "$*" >&2; exit 1; }
shift

method=GET
endpoint=""
while (($# > 0)); do
	case "$1" in
	--method)
		method="$2"
		shift 2
		;;
	--header)
		shift 2
		;;
	--input)
		[[ "$2" == "-" ]] && cat >"$MOCK_STATE/payload.json"
		shift 2
		;;
	*)
		endpoint="$1"
		shift
		;;
	esac
done

case "$endpoint" in
"projects/:id")
	[[ "${MOCK_FAIL_PROJECT:-0}" == "1" ]] && { printf 'not a gitlab project\n' >&2; exit 1; }
	cat "$MOCK_STATE/project.json"
	;;
user)
	cat "$MOCK_STATE/user.json"
	;;
"projects/${MOCK_PROJECT_ID}/protected_branches/main")
	[[ "${MOCK_FAIL_BRANCH:-0}" == "1" ]] && { printf 'main is not protected\n' >&2; exit 1; }
	[[ "$method" == "PATCH" ]] && apply_patch
	cat "$MOCK_STATE/branch.json"
	;;
*)
	printf 'Unexpected endpoint: %s\n' "$endpoint" >&2
	exit 1
	;;
esac
MOCK_GLAB
chmod +x "${MOCK_BIN}/glab"

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

pass() {
	PASS_COUNT=$((PASS_COUNT + 1))
	printf 'ok %d - %s\n' "$PASS_COUNT" "$1"
}

new_case() {
	local name="$1"
	CASE_DIR="${TEST_ROOT}/${name}"
	REPO_DIR="${CASE_DIR}/repo"
	MOCK_STATE="${CASE_DIR}/state"
	MOCK_GLAB_LOG="${CASE_DIR}/glab.log"
	MOCK_PROJECT_ID=555
	export MOCK_STATE MOCK_GLAB_LOG MOCK_PROJECT_ID
	unset MOCK_FAIL_PATCH MOCK_FAIL_PROJECT MOCK_FAIL_BRANCH
	mkdir -p "$MOCK_STATE" "$REPO_DIR"
	git init -q "$REPO_DIR"
	: >"$MOCK_GLAB_LOG"
	printf '%s\n' '{"id":555,"path_with_namespace":"group/project"}' >"$MOCK_STATE/project.json"
	printf '%s\n' '{"id":7,"username":"bertie"}' >"$MOCK_STATE/user.json"
}

seed_branch() {
	printf '%s\n' "$1" >"$MOCK_STATE/branch.json"
}

run_main_push() {
	(
		cd "$REPO_DIR"
		PATH="${MOCK_BIN}:${PATH}" zsh -c '
			source "$1"
			shift
			gitlab-main-push "$@"
		' _ "$ZSH_FUNCTIONS" "$@"
	)
}

# Run the function from a directory that is not a Git repository.
run_outside_git() {
	(
		cd "$CASE_DIR"
		PATH="${MOCK_BIN}:${PATH}" zsh -c '
			source "$1"
			gitlab-main-push
		' _ "$ZSH_FUNCTIONS"
	)
}

# Branch with a role entry (id 1), another user (id 2), and no current user.
standard_branch() {
	cat <<'JSON'
{"name":"main","allow_force_push":false,"code_owner_approval_required":false,
 "merge_access_levels":[{"id":3,"access_level":40}],
 "push_access_levels":[
   {"id":1,"access_level":40,"user_id":null,"group_id":null},
   {"id":2,"access_level":null,"user_id":99,"group_id":null}
 ]}
JSON
}

# Read the ids still present in the mocked push allowlist.
remaining_ids() {
	jq -c '[.push_access_levels[].id] | sort' "$MOCK_STATE/branch.json"
}

membership() {
	jq -c '[.push_access_levels[] | select(.user_id == 7)] | length' "$MOCK_STATE/branch.json"
}

payload_is_user_add_only() {
	jq -e '. == {allowed_to_push: [{user_id: 7}]}' "$MOCK_STATE/last-payload.json" >/dev/null
}

# Status reports non-membership and never writes.
new_case status-not-member
seed_branch "$(standard_branch)"
output="$(run_main_push status)"
[[ "$output" == *"group/project main: bertie is not in the explicit push allowlist"* ]] ||
	fail "status did not report non-membership: $output"
[[ ! -f "$MOCK_STATE/payload.json" ]] || fail "status sent a write payload"
[[ "$(remaining_ids)" == '[1,2]' ]] || fail "status changed the allowlist"
pass "status reports non-membership without writing"

# Toggle adds the current user and keeps unrelated entries.
new_case add
seed_branch "$(standard_branch)"
output="$(run_main_push)"
[[ "$output" == *"added bertie to the explicit push allowlist"* ]] || fail "toggle did not report addition: $output"
payload_is_user_add_only || fail "add payload was not a single user entry"
[[ "$(membership)" == "1" ]] || fail "current user missing after add"
[[ "$(remaining_ids)" == '[1,2,1007]' ]] || fail "unrelated entries were not preserved: $(remaining_ids)"
jq -e '.allow_force_push == false and (.merge_access_levels | length) == 1' "$MOCK_STATE/branch.json" >/dev/null ||
	fail "unrelated branch settings changed"
grep -q 'projects/555/protected_branches/main' "$MOCK_GLAB_LOG" || fail "project id from project endpoint was not used"
grep -q 'projects/:id' "$MOCK_GLAB_LOG" || fail "project was not resolved through the repository placeholder"
pass "toggle adds the user and preserves unrelated entries"

# Status then reports membership.
new_case status-member
seed_branch '{"name":"main","push_access_levels":[{"id":21,"access_level":null,"user_id":7}]}'
output="$(run_main_push status)"
[[ "$output" == *"is in the explicit push allowlist (ids: 21)"* ]] || fail "status did not report membership: $output"
[[ ! -f "$MOCK_STATE/payload.json" ]] || fail "status sent a write payload"
pass "status reports membership without writing"

# Toggle removes only the current user's explicit entries.
new_case remove
seed_branch '{"name":"main","allow_force_push":true,"push_access_levels":[
	{"id":1,"access_level":40},{"id":2,"access_level":null,"user_id":99},
	{"id":21,"access_level":null,"user_id":7},{"id":22,"access_level":null,"user_id":7}]}'
output="$(run_main_push)"
[[ "$output" == *"removed bertie from the explicit push allowlist"* ]] || fail "toggle did not report removal: $output"
[[ "$output" == *"may still be allowed"* ]] || fail "removal did not warn about remaining access paths"
jq -e '.allowed_to_push | sort_by(.id) == [{"id":21,"_destroy":true},{"id":22,"_destroy":true}]' "$MOCK_STATE/last-payload.json" >/dev/null ||
	fail "remove payload did not destroy only the current user's entries"
[[ "$(membership)" == "0" ]] || fail "current user still present after remove"
[[ "$(remaining_ids)" == '[1,2]' ]] || fail "removal touched unrelated entries: $(remaining_ids)"
jq -e '.allow_force_push == true' "$MOCK_STATE/branch.json" >/dev/null || fail "unrelated branch settings changed"
pass "toggle removes only the current user's entries"

# Sole explicit user is removed without dropping the protection rule.
new_case remove-sole-user
seed_branch '{"name":"main","push_access_levels":[{"id":21,"access_level":null,"user_id":7}]}'
run_main_push >/dev/null
[[ "$(jq -c '.push_access_levels' "$MOCK_STATE/branch.json")" == "[]" ]] || fail "sole user entry was not removed"
jq -e '.name == "main"' "$MOCK_STATE/branch.json" >/dev/null || fail "protection rule was lost"
pass "sole user entry is removed without unprotecting main"

# Outside a Git repository nothing is requested or written.
new_case outside-git
seed_branch "$(standard_branch)"
if run_outside_git >/dev/null 2>&1; then
	fail "command succeeded outside a Git repository"
fi
[[ ! -s "$MOCK_GLAB_LOG" ]] || fail "glab was called outside a Git repository"
pass "fails without API calls outside a Git repository"

# Missing protection fails before any write.
new_case missing-rule
seed_branch "$(standard_branch)"
export MOCK_FAIL_BRANCH=1
if run_main_push >/dev/null 2>&1; then
	fail "command succeeded without a protected main"
fi
unset MOCK_FAIL_BRANCH
[[ ! -f "$MOCK_STATE/payload.json" ]] || fail "write attempted without a protected main"
pass "fails before writing when main is not protected"

# Inherited protection is left to the parent group.
new_case inherited
seed_branch '{"name":"main","inherited":true,"push_access_levels":[{"id":1,"access_level":40}]}'
if output="$(run_main_push 2>&1)"; then
	fail "command succeeded on inherited protection"
fi
[[ "$output" == *"inherited from a parent group"* ]] || fail "inherited protection error missing: $output"
[[ ! -f "$MOCK_STATE/payload.json" ]] || fail "write attempted on inherited protection"
pass "fails before writing when protection is inherited"

# Malformed project response fails before any write.
new_case invalid-project
seed_branch "$(standard_branch)"
printf '%s\n' '{}' >"$MOCK_STATE/project.json"
if run_main_push >/dev/null 2>&1; then
	fail "command succeeded with a malformed project response"
fi
[[ ! -f "$MOCK_STATE/payload.json" ]] || fail "write attempted with a malformed project response"
pass "fails before writing on a malformed project response"

# Malformed protected branch response fails before any write.
new_case invalid-branch
seed_branch '{"name":"main","push_access_levels":"nope"}'
if run_main_push >/dev/null 2>&1; then
	fail "command succeeded with a malformed protected branch response"
fi
[[ ! -f "$MOCK_STATE/payload.json" ]] || fail "write attempted with a malformed protected branch response"
pass "fails before writing on a malformed protected branch response"

# A rejected PATCH never reports success.
new_case rejected-patch
seed_branch "$(standard_branch)"
export MOCK_FAIL_PATCH=1
if output="$(run_main_push 2>&1)"; then
	fail "command reported success after a rejected PATCH"
fi
unset MOCK_FAIL_PATCH
[[ "$output" == *"update of group/project main failed"* ]] || fail "PATCH failure was not reported: $output"
[[ "$output" != *"added bertie"* ]] || fail "success message printed after a rejected PATCH"
pass "rejected PATCH fails without reporting success"

printf '1..%d\n' "$PASS_COUNT"
