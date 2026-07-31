#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[10-system-update] %s\n' "$*"
}

fail() {
  printf '[10-system-update] ERROR: %s\n' "$*" >&2
  exit 1
}

if ! command -v sudo >/dev/null 2>&1; then
  fail "sudo is required to update the system."
fi

log "Updating package metadata."
sudo env DEBIAN_FRONTEND=noninteractive apt-get update

log "Performing a full system upgrade."
sudo env DEBIAN_FRONTEND=noninteractive apt-get -y full-upgrade

if [[ -f /var/run/reboot-required ]]; then
  log "A reboot is required to finish applying updates."
fi
