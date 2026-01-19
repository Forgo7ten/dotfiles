#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

function install_iterm2() {
    brew install --cask iterm2
}

function uninstall_iterm2() {
    brew uninstall --cask iterm2
}

function initialize_iterm2() {
    while ! open -g "/Applications/iTerm.app"; do
        sleep 2
    done
}

function main() {
    install_iterm2
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi