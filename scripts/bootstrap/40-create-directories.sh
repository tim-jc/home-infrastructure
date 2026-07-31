#!/usr/bin/env bash
set -euo pipefail

log() {
    printf '[40-create-directories] %s\n' "$*"
}

fail() {
    printf '[40-create-directories] ERROR: %s\n' "$*" >&2
    exit 1
}

SERVICES_ROOT="/srv/services"
TARGET_USER="${SUDO_USER:-${USER:-}}"

if [[ -z "$TARGET_USER" ]]; then
    fail "Unable to determine target user."
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    fail "User '$TARGET_USER' does not exist."
fi

log "Creating directory structure."

sudo mkdir -p \
    "$SERVICES_ROOT/compose" \
    "$SERVICES_ROOT/config" \
    "$SERVICES_ROOT/data" \
    "$SERVICES_ROOT/logs"

log "Setting ownership."

sudo chown -R "$TARGET_USER:$TARGET_USER" "$SERVICES_ROOT"

log "Setting permissions."

sudo chmod 755 "$SERVICES_ROOT"
sudo chmod 755 \
    "$SERVICES_ROOT/compose" \
    "$SERVICES_ROOT/config" \
    "$SERVICES_ROOT/data" \
    "$SERVICES_ROOT/logs"

log "Validating directory structure."

for dir in compose config data logs; do
    [[ -d "$SERVICES_ROOT/$dir" ]] \
        || fail "Directory '$SERVICES_ROOT/$dir' was not created."
done

log "Directory structure created successfully."