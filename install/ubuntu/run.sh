#!/usr/bin/env bash

set -Eeuo pipefail

function install_MesloLGS_ttf(){
    # 1. 定义字体数组
    fonts=(
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
    )

    # 2. 检查并创建目录
    font_dir="$HOME/.local/share/fonts"
    if [ ! -d "$font_dir" ]; then
        mkdir -p "$font_dir"
    fi

    # 3. 下载并刷新
    echo "正在下载 MesloLGS NF 字体..."
    for url in "${fonts[@]}"; do
        # 提取并解码文件名
        filename=$(basename "${url//%20/ }")
        echo " -> 正在下载: $filename"
        # -s: 静默模式, -S: 显示错误, -L: 跟随重定向
        curl -sSL -o "$font_dir/$filename" "$url"
    done

    echo "正在刷新字体缓存..."
    fc-cache -f
    echo "完成！MesloLGS NF 字体已就绪。"
}

function install_packages(){
    # 安装p10k字体 MesloLGS
    install_MesloLGS_ttf
}


function main() {
    install_packages
}

main