#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[20-install-packages] %s\n' "$*"
}

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
sudo apt-get install -y "${REQUIRED_PACKAGES[@]}"