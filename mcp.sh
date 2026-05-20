#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_CONFIG_FILE="${MCP_CONFIG_FILE:-$HOME/.config/mcp/mcp.json}"

copy_file() {
	local source="$1"
	local destination="$2"

	if [[ ! -f "$source" ]]; then
		echo "Missing file: ${source}" >&2
		return 1
	fi

	mkdir -p "$(dirname "$destination")"
	cp -v "$source" "$destination"
}

copy_file "${SCRIPT_DIR}/config/mcp/mcp.json" "$MCP_CONFIG_FILE"
