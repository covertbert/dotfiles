#!/usr/bin/env bash
# Verifies the pi-web LaunchAgent template renders to a valid plist with no
# placeholder tokens left behind.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${ROOT_DIR}/config/launchd/com.blackmanrgh.pi-web.plist"
RENDERED="$(mktemp -t pi-web-plist)"
trap 'rm -f "$RENDERED"' EXIT

sed -e "s|__PI_WEB_BIN__|/fake/bin/pi-web|" -e "s|__NODE_BIN_DIR__|/fake/node/bin|" \
	"$TEMPLATE" >"$RENDERED"

if grep -q '__PI_WEB_BIN__\|__NODE_BIN_DIR__' "$RENDERED"; then
	echo "not ok 1 - rendered plist has no placeholders" >&2
	echo "1..1"
	exit 1
fi

plutil -lint "$RENDERED" >/dev/null

grep -q '<string>/fake/bin/pi-web</string>' "$RENDERED"
grep -q '<string>127.0.0.1</string>' "$RENDERED"

echo "ok 1 - template renders to a looping-back plist"
echo "1..1"
