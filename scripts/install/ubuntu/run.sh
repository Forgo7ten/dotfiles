#!/usr/bin/env bash

set -Eeuo pipefail


function install_packages(){
    # 安装direnv
    sudo apt-get install direnv -y
    # 安装zoxide
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
}


function main() {
    install_packages
}

main