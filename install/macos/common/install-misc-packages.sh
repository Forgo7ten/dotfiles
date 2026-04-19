#!/usr/bin/env bash

# 设置脚本在遇到错误时立即退出
# -E: 承接 ERR trap
# -e: 脚本中命令报错即退出
# -u: 使用未定义变量即报错
# -o pipefail: 管道命令中只要有一个失败，整个管道就视为失败
set -Eeuo pipefail

# 调试模式
if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

# 定义 macOS 对应的软件包列表
readonly PACKAGES=(
    # zoxide
)

# 检查 Homebrew 是否已安装
function check_brew() {
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew is not installed. Please install it first from https://brew.sh/"
        exit 1
    fi
}

function install_brew_packages() {
    if [ ${#PACKAGES[@]} -eq 0 ]; then
        # echo "No packages defined. Skipping installation."
        return 0
    fi
    echo "Updating Homebrew..."
    brew update

    echo "Installing packages..."
    # 使用 brew install 安装，brew 会自动处理已安装的包
    brew install "${PACKAGES[@]}"
}

function uninstall_brew_packages() {
    echo "Uninstalling packages..."
    brew uninstall "${PACKAGES[@]}"
}

function install_other_packages() {
}

function main() {
    check_brew
    install_brew_packages
    install_other_packages
}

# 仅当脚本被直接执行（而非被 source）时调用 main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi