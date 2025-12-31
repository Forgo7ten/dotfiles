#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

function main() {
    echo "../install/macos/arm64/prepare_arm64_system.sh"
    # 可以添加一些package的安装
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
