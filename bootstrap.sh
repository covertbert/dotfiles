#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_step() {
	local script="$1"

	echo "==> Running ${script}"
	"${SCRIPT_DIR}/${script}"
}

run_step "defaults.sh"
run_step "config.sh"
run_step "brew.sh"
