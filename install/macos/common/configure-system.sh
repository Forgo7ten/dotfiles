#!/usr/bin/env bash

# macOS 系统设置初始化（defaults 写入）
# -E: 承接 ERR trap
# -e: 脚本中命令报错即退出
# -u: 使用未定义变量即报错
# -o pipefail: 管道命令中只要有一个失败，整个管道就视为失败
set -Eeuo pipefail

# 调试模式
if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

function configure_system() {
    # 退出 `系统设置` 应用程序（未运行时 osascript 会报错，属预期，忽略）
    osascript -e 'quit app "System Settings"' 2>/dev/null || true

    # 系统设置 - 桌面与程序坞 - 在程序坞中显示建议App和最近使用的App 【关】
    defaults write com.apple.dock show-recents -bool false

    # 重启 Dock 使设置生效（无 GUI 会话时 killall 会报错，属预期，忽略）
    killall Dock 2>/dev/null || true

    # 系统设置 - 电池 - 选项 - 使用电源适配器供电且显示器关闭时，防止自动进入睡眠 【开】
    sudo pmset -c sleep 0
}

function main() {
    configure_system
}

# 仅当脚本被直接执行（而非被 source）时调用 main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
