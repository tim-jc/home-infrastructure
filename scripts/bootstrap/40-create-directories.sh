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
TARGET_USER="${BOOTSTRAP_USER:-${SUDO_USER:-${USER:-}}}"
DIRECTORY_MODE="750"

if ! command -v sudo >/dev/null 2>&1; then
    fail "sudo is required to create the service directories."
fi

if [[ -z "$TARGET_USER" ]]; then
    fail "Unable to determine the target user; set BOOTSTRAP_USER explicitly."
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    fail "User '$TARGET_USER' does not exist."
fi

if [[ "$TARGET_USER" == root ]]; then
    fail "Refusing to make root the service owner; set BOOTSTRAP_USER to the administrative account."
fi

TARGET_GROUP="$(id -gn "$TARGET_USER")"

directories=(
    "$SERVICES_ROOT"
    "$SERVICES_ROOT/compose"
    "$SERVICES_ROOT/config"
    "$SERVICES_ROOT/data"
    "$SERVICES_ROOT/logs"
)

for directory in "${directories[@]}"; do
    if [[ -L "$directory" ]]; then
        fail "Refusing to manage symbolic link '$directory'."
    fi
done

log "Creating directory structure."

sudo install -d \
    -o "$TARGET_USER" \
    -g "$TARGET_GROUP" \
    -m "$DIRECTORY_MODE" \
    "${directories[@]}"

log "Validating directory structure."

for directory in "${directories[@]}"; do
    if [[ ! -d "$directory" || -L "$directory" ]]; then
        fail "Expected '$directory' to be a real directory."
    fi

    actual_attributes="$(stat --format='%U:%G %a' "$directory")"
    expected_attributes="$TARGET_USER:$TARGET_GROUP $DIRECTORY_MODE"

    if [[ "$actual_attributes" != "$expected_attributes" ]]; then
        fail "Directory '$directory' has '$actual_attributes'; expected '$expected_attributes'."
    fi
done

log "Directory structure created successfully."
