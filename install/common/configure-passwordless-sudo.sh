#!/usr/bin/env bash

set -Eeuo pipefail

USER_NAME="$(id -un)"
SUDOERS_FILE="/etc/sudoers.d/${USER_NAME}"

sudo tee "${SUDOERS_FILE}" >/dev/null <<EOF
# Passwordless sudo for ${USER_NAME}
${USER_NAME} ALL=(ALL) NOPASSWD: ALL
EOF

sudo chmod 440 "${SUDOERS_FILE}"
sudo visudo -c
