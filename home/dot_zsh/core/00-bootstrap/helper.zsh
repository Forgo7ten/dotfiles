# --- 命令助手系统 ---

if [ -n "$ZSH_VERSION" ]; then
    typeset -g -A _F_REGISTRY
    typeset -g -a _F_ORDER
elif [ -n "$BASH_VERSION" ]; then
    declare -g -A _F_REGISTRY
    declare -g -a _F_ORDER
fi

fregister() {
    local cmd="$1"
    local info="$2"
    
    if [[ -z "$cmd" || -z "$info" ]]; then
        echo "Usage: fregister <command> <description>"
        return 1
    fi

    # 检查是否是重复注册，如果没注册过，则记录顺序
    # Zsh 中判断关联数组 key 是否存在
    if [[ -z "${_F_REGISTRY[$cmd]}" ]]; then
        _F_ORDER+=("$cmd")
    fi
    
    # 存入说明
    _F_REGISTRY[$cmd]="$info"
}

fhelp() {
    echo -e "\n\033[1;34m=== 已注册的自定义命令 ===\033[0m"
    printf "\033[1m%-20s %s\033[0m\n" "Command" "Description"
    echo "------------------------------------------------------"
    
    local cmd
    for cmd in "${_F_ORDER[@]}"; do
        local desc="${_F_REGISTRY[$cmd]}"
        printf "\033[32m%-20s\033[0m : %s\n" "$cmd" "$desc"
    done
    echo -e "------------------------------------------------------\n"
}