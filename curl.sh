#!/bin/bash

# One-line installer bootstrap.
# Usage (single line, no clone):
#   curl -fsSL https://raw.githubusercontent.com/pierreyvesbaloche/rpi-fan-service/main/curl.sh | sudo bash
#
# It downloads the canonical install.sh from the rpi-fan-service GitHub
# repository and executes it, so the whole install (packages, virtual
# environment, rpi-fan-custom.py, systemd service) runs unattended.
#
# Override the source with environment variables:
#   RPI_FAN_REPO_URL   GitHub repository base URL
#   RPI_FAN_RAW_URL    raw file base URL (defaults to <repo>/main raw files)

set -o pipefail
set -euo pipefail

REPO_URL="${RPI_FAN_REPO_URL:-https://github.com/pierreyvesbaloche/rpi-fan-service}"
RAW_URL="${RPI_FAN_RAW_URL:-https://raw.githubusercontent.com/${REPO_URL#https://github.com/}/main}"
INSTALL_SH_URL="$RAW_URL/install.sh"

command -v curl > /dev/null 2>&1 || {
	printf "curl is required. Install it first: sudo apt install curl\n"
	exit 1
}

if [ -t 0 ]; then
	# stdin is a terminal, so we were executed from a file, not piped in:
	# fetch and run the canonical install.sh.
	printf "Fetching %s\n" "$INSTALL_SH_URL"
	exec curl -fsSL --fail "$INSTALL_SH_URL" | bash
fi
if [ "${1:-}" = "--install" ]; then
	# Piped in with options (curl ... | sudo bash -- --install):
	# fetch and run the canonical install.sh with those options.
	exec curl -fsSL --fail "$INSTALL_SH_URL" | bash -s -- "$@"
fi

# Piped in bare (curl -fsSL ... | sudo bash): this script's stdin has already
# been consumed as script text, so fetch install.sh and run it.
exec curl -fsSL --fail "$INSTALL_SH_URL" | bash
