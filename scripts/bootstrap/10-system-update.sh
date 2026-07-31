#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[10-system-update] %s\n' "$*"
}

export DEBIAN_FRONTEND=noninteractive

log "Performing upgrade"
sudo apt-get update
sudo apt-get -y full-upgrade
sudo apt-get autoremove -y
sudo apt-get autoclean

if [[ -f /var/run/reboot-required ]]; then
    log "Reboot required."
fi