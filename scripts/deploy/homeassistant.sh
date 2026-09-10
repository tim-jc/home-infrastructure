#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[deploy-homeassistant] %s\n' "$*"
}

fail() {
  printf '[deploy-homeassistant] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: homeassistant.sh [--upgrade]

Without options, reconcile Home Assistant without refreshing an image that is
already present. Use --upgrade to pull the current image referenced by Compose
before reconciling the container.
EOF
}

upgrade=false

case "${1:-}" in
  "")
    ;;
  --upgrade)
    upgrade=true
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    fail "Unknown option '$1'."
    ;;
esac

if (( $# > 1 )); then
  usage >&2
  fail "Only one option may be supplied."
fi

for command in docker id stat; do
  if ! command -v "$command" >/dev/null 2>&1; then
    fail "Required command '$command' is unavailable. Complete host bootstrap first."
  fi
done

if ! docker info >/dev/null 2>&1; then
  fail "Docker is unavailable to the current user. Check that Docker is running and start a new login session after Docker group changes."
fi

if ! docker compose version >/dev/null 2>&1; then
  fail "The Docker Compose plugin is unavailable. Complete host bootstrap first."
fi

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_directory/../.." && pwd)"
compose_file="$repository_root/compose/homeassistant/compose.yaml"
state_directory="/srv/services/data/homeassistant"
target_user="${DEPLOY_USER:-${SUDO_USER:-${USER:-}}}"
directory_mode="750"

if [[ ! -f "$compose_file" ]]; then
  fail "Compose definition '$compose_file' does not exist."
fi

if [[ -z "$target_user" ]] || ! id "$target_user" >/dev/null 2>&1; then
  fail "Unable to identify a valid deployment user; set DEPLOY_USER explicitly."
fi

if [[ "$target_user" == root ]]; then
  fail "Refusing to use root as the state owner; set DEPLOY_USER to the administrative account."
fi

target_group="$(id -gn "$target_user")"

if [[ -L "$state_directory" ]]; then
  fail "Refusing to manage symbolic link '$state_directory'."
fi

if [[ ! -e "$state_directory" ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    fail "sudo is required to create '$state_directory'."
  fi

  log "Creating Home Assistant state directory."
  sudo install -d \
    -o "$target_user" \
    -g "$target_group" \
    -m "$directory_mode" \
    "$state_directory"
fi

if [[ ! -d "$state_directory" || -L "$state_directory" ]]; then
  fail "Expected '$state_directory' to be a real directory."
fi

actual_attributes="$(stat --format='%U:%G %a' "$state_directory")"
expected_attributes="$target_user:$target_group $directory_mode"

if [[ "$actual_attributes" != "$expected_attributes" ]]; then
  fail "State directory has '$actual_attributes'; expected '$expected_attributes'. Correct it explicitly before deployment."
fi

for host_path in /etc/localtime /run/dbus; do
  if [[ ! -e "$host_path" ]]; then
    fail "Required host path '$host_path' does not exist."
  fi
done

compose=(docker compose --file "$compose_file")

log "Validating the Home Assistant Compose definition."
"${compose[@]}" config --quiet

if [[ "$upgrade" == true ]]; then
  log "Pulling the configured Home Assistant image for an intentional upgrade."
  "${compose[@]}" pull homeassistant
else
  log "Reconciling without refreshing an image that is already present."
fi

"${compose[@]}" up -d --pull missing homeassistant

container_id="$("${compose[@]}" ps --quiet homeassistant)"
if [[ -z "$container_id" ]]; then
  fail "Compose did not return a Home Assistant container."
fi

if [[ "$(docker inspect --format '{{.State.Running}}' "$container_id")" != true ]]; then
  fail "Home Assistant container '$container_id' is not running."
fi

health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}not-configured{{end}}' "$container_id")"
if [[ "$health_status" == unhealthy ]]; then
  fail "Home Assistant container '$container_id' reports an unhealthy status."
fi

log "Home Assistant is running (health: $health_status)."
log "Persistent state: $state_directory"
log "Compose definition: $compose_file"
