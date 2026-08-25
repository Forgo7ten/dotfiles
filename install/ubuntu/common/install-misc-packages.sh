#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

# 本脚本安装的工具会部署到 ~/.local/bin（如 mise），提前加入 PATH，
# 供后续各工具的已安装检测统一使用 command -v
export PATH="$HOME/.local/bin:$PATH"

readonly PACKAGES=(
    git
    vim
    wget
    curl
    net-tools
    zsh
    tree
    htop
    jnettop
    p7zip-full
    unzip
    busybox
    gpg
)

function install_apt_packages() {
    sudo apt-get update
    sudo apt-get install -y "${PACKAGES[@]}"
}

# 安装 mise（版本/运行时管理器）
# - 官方脚本默认安装到 ~/.local/bin/mise，幂等：已安装则跳过
# - 依赖 curl（已在上方 PACKAGES 中），故必须在 apt 安装之后调用
# - shell 激活由 dot_zsh/core/40-runtime/10-mise.zsh 负责，此处只装二进制
function install_mise() {
    if command -v mise &> /dev/null; then
        echo "mise is already installed, skipping."
        return 0
    fi

    echo "Installing mise..."
    curl https://mise.run | sh
}

function uninstall_apt_packages() {
    sudo apt-get remove -y "${PACKAGES[@]}"
}

function main() {
    install_apt_packages
    # 顺序依赖：mise 安装依赖 apt 提供的 curl
    install_mise
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
