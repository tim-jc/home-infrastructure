#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

log() {
  printf '[30-install-docker] %s\n' "$*"
}

fail() {
  printf '[30-install-docker] ERROR: %s\n' "$*" >&2
  exit 1
}

if ! command -v sudo >/dev/null 2>&1; then
  fail "sudo is required to install and manage Docker."
fi

if [[ ! -r /etc/os-release ]]; then
  fail "Cannot identify the operating system: /etc/os-release is unavailable."
fi

# shellcheck disable=SC1091
source /etc/os-release

case "${ID:-}" in
  debian|raspbian)
    ;;
  *)
    fail "Unsupported operating system '${ID:-unknown}'; expected Debian or Raspberry Pi OS."
    ;;
esac

if [[ -z "${VERSION_CODENAME:-}" ]]; then
  fail "VERSION_CODENAME is missing from /etc/os-release."
fi

architecture="$(dpkg --print-architecture)"
if [[ "$architecture" != "arm64" ]]; then
  fail "Unsupported architecture '$architecture'; this bootstrap currently supports arm64 only."
fi

target_user="${SUDO_USER:-${USER:-}}"

if [[ -z "$target_user" ]]; then
  fail "Unable to determine the user who should receive Docker group membership."
fi

if ! id "$target_user" >/dev/null 2>&1; then
  fail "Target user '$target_user' does not exist."
fi

if command -v docker >/dev/null 2>&1; then
  if ! docker compose version >/dev/null 2>&1; then
    fail "Docker is installed but the Compose plugin is unavailable. Resolve the existing Docker installation before rerunning."
  fi

  log "Docker Engine and the Compose plugin are already installed."
else
  log "Configuring Docker's official Debian package repository."

  temporary_key="$(mktemp)"
  temporary_source="$(mktemp)"

  cleanup() {
    rm -f -- "$temporary_key" "$temporary_source"
  }

  trap cleanup EXIT

  curl --fail --silent --show-error --location \
    https://download.docker.com/linux/debian/gpg \
    --output "$temporary_key"

  printf '%s\n' \
    'Types: deb' \
    'URIs: https://download.docker.com/linux/debian' \
    "Suites: $VERSION_CODENAME" \
    'Components: stable' \
    "Architectures: $architecture" \
    'Signed-By: /etc/apt/keyrings/docker.asc' \
    >"$temporary_source"

  sudo install -d -m 0755 /etc/apt/keyrings
  sudo install -m 0644 "$temporary_key" /etc/apt/keyrings/docker.asc
  sudo install -m 0644 "$temporary_source" /etc/apt/sources.list.d/docker.sources

  sudo apt-get update
  sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  log "Docker Engine and the Compose plugin were installed."
fi

log "Enabling and starting the Docker service."
sudo systemctl enable --now docker

if ! getent group docker >/dev/null 2>&1; then
  fail "The Docker group does not exist after installation."
fi

if id -nG "$target_user" | tr ' ' '\n' | grep -qx docker; then
  log "User '$target_user' is already a member of the Docker group."
else
  sudo usermod -aG docker "$target_user"
  log "Added user '$target_user' to the Docker group."
  log "Log out and back in before using Docker without sudo."
fi

log "Validating Docker Engine."
sudo docker info >/dev/null

log "Validating Docker Compose."
sudo docker compose version >/dev/null

log "Docker installation complete."
log "Docker Engine: available"
log "Docker Compose: available"
log "Docker service: enabled and running"
log "Docker group: configured for '$target_user'"