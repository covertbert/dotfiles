#!/usr/bin/env bash
# Checks router lifecycle and rendering without loading a model or using launchd.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d -t llama-router-test)"
trap 'rm -rf "$TEST_DIR"' EXIT
export HOME="${TEST_DIR}/fake home & user"
export LLAMA_TEST_STATE="${TEST_DIR}/loaded"
export PATH="${TEST_DIR}/bin:$PATH"
mkdir -p "${TEST_DIR}/bin" "${HOME}/.local/bin" "${HOME}/.config/llama"
cp "${ROOT_DIR}/config/llama/models.ini" "${HOME}/.config/llama/models.ini"

cat >"${HOME}/.local/bin/llama" <<'EOF'
#!/bin/bash
printf 'version: 1.0.0-dev (build 12651, commit a8f8294c4)\n'
EOF
cat >"${TEST_DIR}/bin/launchctl" <<'EOF'
#!/bin/bash
case "$1" in
bootstrap) touch "$LLAMA_TEST_STATE" ;;
bootout) [ "${FAIL_STOP:-0}" = 0 ] || exit 1; rm -f "$LLAMA_TEST_STATE" ;;
print) test -f "$LLAMA_TEST_STATE" ;;
*) exit 1 ;;
esac
EOF
cat >"${TEST_DIR}/bin/curl" <<'EOF'
#!/bin/bash
[ "${FAIL_HEALTH:-0}" = 0 ] || exit 7
case "$*" in
*/health*) printf '{"status":"ok"}\n' ;;
*/models*) printf '{"data":[{"id":"inkling-2-mini","status":{"value":"unloaded"}}]}\n' ;;
*) exit 22 ;;
esac
EOF
cat >"${TEST_DIR}/bin/sleep" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "${HOME}/.local/bin/llama" "${TEST_DIR}/bin/"*

bash "${ROOT_DIR}/bin/dotfiles" llama install >"${TEST_DIR}/install.log"
grep -q 'already installed' "${TEST_DIR}/install.log"
bash "${ROOT_DIR}/bin/dotfiles" llama start >"${TEST_DIR}/start.log"
PLIST="${HOME}/Library/LaunchAgents/com.blackmanrgh.llama-router.plist"
plutil -lint "$PLIST" >/dev/null
python3 - "$PLIST" "$ROOT_DIR" <<'PY'
import json
import os
import plistlib
import sys

with open(sys.argv[1], "rb") as f:
    p = plistlib.load(f)
args = p["ProgramArguments"]
assert args[:2] == [os.path.join(os.environ["HOME"], ".local/bin/llama"), "serve"]
expected = {
    "--host": "127.0.0.1", "--port": "9931", "--cors-origins": "localhost",
    "-ngl": "auto", "-ub": "64", "-c": "32768", "-np": "1",
    "--models-max": "1", "--models-memory-margin": "1024",
    "--sleep-idle-seconds": "120",
    "--models-preset": os.path.join(os.environ["HOME"], ".config/llama/models.ini"),
}
for key, value in expected.items():
    assert args[args.index(key) + 1] == value, key
assert "--no-models-autoload" in args
assert not any(x in args for x in ["--model", "-m", "-hf", "--hf-repo"])
assert p["WorkingDirectory"] == os.environ["HOME"]
assert p["StandardErrorPath"] == os.path.join(os.environ["HOME"], "Library/Logs/llama-router.log")
assert "__HOME__" not in str(p) and "__LLAMA_BIN__" not in str(p)
with open(os.path.join(sys.argv[2], "config/pi/models.json")) as f:
    provider = json.load(f)["providers"]["llama.cpp"]
assert "apiKey" not in provider and "models" not in provider
assert provider["modelOverrides"]["inkling-2-mini"]["maxTokens"] == 4096
PY
printf 'ok 1 - pinned install is idempotent; start renders paths and conservative flags\n'

bash "${ROOT_DIR}/bin/dotfiles" llama status >"${TEST_DIR}/status.log"
grep -q 'inkling-2-mini (unloaded)' "${TEST_DIR}/status.log"
if FAIL_STOP=1 bash "${ROOT_DIR}/bin/dotfiles" llama stop &>/dev/null; then
	echo 'stop must report a launchctl failure' >&2
	exit 1
fi
bash "${ROOT_DIR}/bin/dotfiles" llama stop >/dev/null
test ! -f "$LLAMA_TEST_STATE"
bash "${ROOT_DIR}/bin/dotfiles" llama stop >/dev/null
printf 'ok 2 - status reports model state; stop is idempotent and does not hide failures\n'

if FAIL_HEALTH=1 bash "${ROOT_DIR}/bin/dotfiles" llama start &>/dev/null; then
	echo 'start must fail when health never succeeds' >&2
	exit 1
fi
if bash "${ROOT_DIR}/bin/dotfiles" llama invalid &>/dev/null; then
	exit 1
fi
rm "${HOME}/.local/bin/llama"
if bash "${ROOT_DIR}/bin/dotfiles" llama start &>/dev/null; then
	exit 1
fi
if bash "${ROOT_DIR}/bin/dotfiles" llama install &>/dev/null; then
	echo 'install must report a download failure' >&2
	exit 1
fi
printf 'ok 3 - unhealthy router, missing binary, bad action, and download failure are rejected\n'
printf '1..3\n'
