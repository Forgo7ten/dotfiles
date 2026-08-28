# --- 命令助手系统 ---
# mycmds                             列出已注册的自定义命令
# mycmds describe <command> <description>   注册/更新命令说明
# mycmds help                        打印帮助

if [ -n "$ZSH_VERSION" ]; then
    typeset -g -A _MYCMDS_REGISTRY
    typeset -g -a _MYCMDS_ORDER
elif [ -n "$BASH_VERSION" ]; then
    declare -g -A _MYCMDS_REGISTRY
    declare -g -a _MYCMDS_ORDER
fi

# 打印帮助（供 mycmds 内部使用；fd 可选，指定输出到哪个文件描述符）
__mycmds_help() {
    local fd="${1:-1}"
    echo "Usage:" >&"$fd"
    echo "  mycmds                              列出已注册的自定义命令" >&"$fd"
    echo "  mycmds describe <command> <desc>    注册/更新命令说明" >&"$fd"
    echo "  mycmds help                         打印帮助" >&"$fd"
}

mycmds() {
    local sub="${1:-}"
    [[ $# -gt 0 ]] && shift

    case "$sub" in
        describe)
            local cmd="${1:-}"
            local info="${2:-}"

            if [[ -z "$cmd" || -z "$info" ]]; then
                echo "Usage: mycmds describe <command> <description>"
                return 1
            fi

            # 检查是否是重复注册，如果没注册过，则记录顺序
            if [[ -z "${_MYCMDS_REGISTRY[$cmd]}" ]]; then
                _MYCMDS_ORDER+=("$cmd")
            fi

            # 存入说明
            _MYCMDS_REGISTRY[$cmd]="$info"
            ;;
        list|ls|"")
            echo -e "\n\033[1;34m=== 已注册的自定义命令 ===\033[0m"
            printf "\033[1m%-20s %s\033[0m\n" "Command" "Description"
            echo "------------------------------------------------------"

            local cmd
            for cmd in "${_MYCMDS_ORDER[@]}"; do
                local desc="${_MYCMDS_REGISTRY[$cmd]}"
                printf "\033[32m%-20s\033[0m : %s\n" "$cmd" "$desc"
            done
            echo -e "------------------------------------------------------\n"
            ;;
        help|-h|--help)
            __mycmds_help 1
            ;;
        *)
            echo "mycmds: 未知子命令: $sub" >&2
            __mycmds_help 2
            return 1
            ;;
    esac
}
