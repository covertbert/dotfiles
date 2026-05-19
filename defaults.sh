#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULTS_DIR="${SCRIPT_DIR}/defaults"

run_defaults() {
	local script="$1"

	echo "==> Applying ${script} defaults"
	bash "${DEFAULTS_DIR}/${script}"
}

run_defaults "system.sh"
run_defaults "chrome.sh"
run_defaults "transmission.sh"
