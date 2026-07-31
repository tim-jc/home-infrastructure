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

for command in curl dpkg getent id install mktemp systemctl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    fail "Required command '$command' is unavailable; run 20-install-packages.sh first."
  fi
done

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

target_user="${BOOTSTRAP_USER:-${SUDO_USER:-${USER:-}}}"

if [[ -z "$target_user" ]]; then
  fail "Unable to determine the target user; set BOOTSTRAP_USER explicitly."
fi

if ! id "$target_user" >/dev/null 2>&1; then
  fail "Target user '$target_user' does not exist."
fi

if [[ "$target_user" == root ]]; then
  fail "Refusing to configure root as the Docker user; set BOOTSTRAP_USER to the administrative account."
fi

log "Configuring Docker's official Debian package repository."

temporary_directory="$(mktemp -d)"
temporary_key="$temporary_directory/docker.asc"
temporary_source="$temporary_directory/docker.sources"

cleanup() {
  rm -rf -- "$temporary_directory"
}

trap cleanup EXIT

curl --fail --silent --show-error --location \
  https://download.docker.com/linux/debian/gpg \
  --output "$temporary_key"

if [[ ! -s "$temporary_key" ]]; then
  fail "Docker repository signing key download was empty."
fi

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

sudo env DEBIAN_FRONTEND=noninteractive apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

log "Docker packages are installed."

log "Enabling and starting the Docker service."
sudo systemctl enable --now docker

if ! getent group docker >/dev/null 2>&1; then
  fail "The Docker group does not exist after installation."
fi

docker_group_entry="$(getent group docker)"
IFS=: read -r _ _ docker_group_id _ <<<"$docker_group_entry"

if [[ -z "$docker_group_id" ]]; then
  fail "Unable to determine the Docker group ID."
fi

if [[ " $(id -G "$target_user") " == *" $docker_group_id "* ]]; then
  log "User '$target_user' is already a member of the Docker group."
else
  sudo usermod -aG docker "$target_user"
  log "Added user '$target_user' to the Docker group."
  log "Log out and back in before using Docker without sudo."
fi

if [[ " $(id -G "$target_user") " != *" $docker_group_id "* ]]; then
  fail "User '$target_user' is not a member of the Docker group after configuration."
fi

log "Validating Docker Engine."
sudo docker info >/dev/null

log "Validating Docker Buildx."
sudo docker buildx version >/dev/null

log "Validating Docker Compose."
sudo docker compose version >/dev/null

if ! sudo systemctl is-active --quiet docker; then
  fail "Docker service is not running."
fi

if ! sudo systemctl is-enabled --quiet docker; then
  fail "Docker service is not enabled."
fi

log "Docker installation complete."
log "Docker Engine: available"
log "Docker Buildx: available"
log "Docker Compose: available"
log "Docker service: enabled and running"
log "Docker group: configured for '$target_user'"
