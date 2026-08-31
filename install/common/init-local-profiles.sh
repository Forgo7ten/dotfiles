#!/usr/bin/env bash

# 初始化机器本地的 shell profile 文件（.bash_aliases / .zshrc.pre / .zshrc）
# 这些文件属于机器本地用户配置，不进仓库，缺失时由此脚本创建
# -E: 承接 ERR trap
# -e: 脚本中命令报错即退出
# -u: 使用未定义变量即报错
# -o pipefail: 管道命令中只要有一个失败，整个管道就视为失败
set -Eeuo pipefail

# 调试模式
if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

function init_local_profiles() {
    # 三个文件都是「不存在才创建」，已存在的不做任何改动
    if [ ! -f "$HOME/.bash_aliases" ]; then
        touch "$HOME/.bash_aliases"
    fi

    if [ ! -f "$HOME/.zshrc.pre" ]; then
        touch "$HOME/.zshrc.pre"
    fi

    # .zshrc 不存在时，创建并写入 .bash_aliases 加载片段
    if [ ! -f "$HOME/.zshrc" ]; then
        cat > "$HOME/.zshrc" <<'EOF'
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
EOF
    fi
}

function main() {
    init_local_profiles
}

# 仅当脚本被直接执行（而非被 source）时调用 main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
