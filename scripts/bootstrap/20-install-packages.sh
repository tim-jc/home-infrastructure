#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[20-install-packages] %s\n' "$*"
}

fail() {
  printf '[20-install-packages] ERROR: %s\n' "$*" >&2
  exit 1
}

if ! command -v sudo >/dev/null 2>&1; then
  fail "sudo is required to install host packages."
fi

REQUIRED_PACKAGES=(
    ca-certificates
    curl
    wget
    git
    rsync
    htop
    nano
    unzip
)

log "Installing required host packages."
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${REQUIRED_PACKAGES[@]}"
