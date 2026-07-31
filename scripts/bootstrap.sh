#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for step in \
    10-system-update.sh \
    20-install-packages.sh \
    30-install-docker.sh \
    40-configure-host.sh \
    50-create-directories.sh
do
    echo
    echo "==> Running ${step}"
    "${SCRIPT_DIR}/bootstrap/${step}"
done