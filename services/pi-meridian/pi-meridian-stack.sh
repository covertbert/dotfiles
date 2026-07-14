#!/usr/bin/env bash

set -euo pipefail

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
LOG_DIR="${PI_MERIDIAN_LOG_DIR:-$HOME/Library/Logs/pi-meridian}"
PROXY_SCRIPT="${PI_MERIDIAN_PROXY_SCRIPT:-$HOME/.local/bin/pi-meridian-proxy.mjs}"
MERIDIAN_HEALTH_URL="http://127.0.0.1:3456/health"
PROXY_HEALTH_URL="http://127.0.0.1:3457/health"

mkdir -p "$LOG_DIR"
exec >>"$LOG_DIR/stack.log" 2>&1

echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') Starting Pi → Meridian stack"

if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
	echo "NVM not found at $NVM_DIR/nvm.sh" >&2
	exit 1
fi

# NVM is not nounset-safe while loading.
set +u
# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"
set -u

if ! NODE_BIN="$(nvm which default 2>/dev/null)" || [[ ! -x "$NODE_BIN" ]]; then
	echo "Default NVM Node not found. Run: dotfiles npm" >&2
	exit 1
fi

NODE_BIN_DIR="$(dirname "$NODE_BIN")"
MERIDIAN_BIN="$NODE_BIN_DIR/meridian"

if [[ ! -x "$MERIDIAN_BIN" ]]; then
	echo "Meridian not installed under default NVM Node. Run: dotfiles npm" >&2
	exit 1
fi

if [[ ! -f "$PROXY_SCRIPT" ]]; then
	echo "Proxy script not found at $PROXY_SCRIPT. Run: dotfiles pi-meridian setup" >&2
	exit 1
fi

export PATH="$NODE_BIN_DIR:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export MERIDIAN_HOST="127.0.0.1"
export MERIDIAN_PORT="3456"
export PI_MERIDIAN_TARGET_PORT="3456"
export PI_MERIDIAN_LISTEN_PORT="3457"

if CLAUDE_BIN="$(command -v claude 2>/dev/null)"; then
	export MERIDIAN_CLAUDE_PATH="$CLAUDE_BIN"
else
	echo "Claude Code not found on PATH. Run: dotfiles brew" >&2
	exit 1
fi

MERIDIAN_PID=""
PROXY_PID=""

# Invoked indirectly by EXIT trap.
# shellcheck disable=SC2329
cleanup() {
	local pid

	for pid in "$PROXY_PID" "$MERIDIAN_PID"; do
		if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
			kill "$pid" 2>/dev/null || true
		fi
	done

	for pid in "$PROXY_PID" "$MERIDIAN_PID"; do
		if [[ -n "$pid" ]]; then
			wait "$pid" 2>/dev/null || true
		fi
	done
}

trap cleanup EXIT
trap 'exit 0' INT TERM HUP

"$MERIDIAN_BIN" >>"$LOG_DIR/meridian.log" 2>&1 &
MERIDIAN_PID=$!

meridian_ready=false
for _ in {1..30}; do
	if ! kill -0 "$MERIDIAN_PID" 2>/dev/null; then
		echo "Meridian exited during startup. Check $LOG_DIR/meridian.log" >&2
		exit 1
	fi

	if curl -fsS --max-time 2 "$MERIDIAN_HEALTH_URL" >/dev/null 2>&1; then
		meridian_ready=true
		break
	fi

	sleep 1
done

if [[ "$meridian_ready" != true ]]; then
	echo "Meridian did not become healthy within 30 seconds." >&2
	exit 1
fi

"$NODE_BIN" "$PROXY_SCRIPT" >>"$LOG_DIR/proxy.log" 2>&1 &
PROXY_PID=$!

proxy_ready=false
for _ in {1..15}; do
	if ! kill -0 "$PROXY_PID" 2>/dev/null; then
		echo "Rewrite proxy exited during startup. Check $LOG_DIR/proxy.log" >&2
		exit 1
	fi

	if curl -fsS --max-time 2 "$PROXY_HEALTH_URL" >/dev/null 2>&1; then
		proxy_ready=true
		break
	fi

	sleep 1
done

if [[ "$proxy_ready" != true ]]; then
	echo "Rewrite proxy did not become healthy within 15 seconds." >&2
	exit 1
fi

echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') Pi → Meridian stack ready"

while kill -0 "$MERIDIAN_PID" 2>/dev/null && kill -0 "$PROXY_PID" 2>/dev/null; do
	sleep 2
done

if ! kill -0 "$MERIDIAN_PID" 2>/dev/null; then
	echo "Meridian stopped unexpectedly. Restarting stack through launchd." >&2
else
	echo "Rewrite proxy stopped unexpectedly. Restarting stack through launchd." >&2
fi

exit 1
