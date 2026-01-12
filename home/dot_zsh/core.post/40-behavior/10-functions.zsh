## 设置代理
proxy_on() {
    local addr=${1:-"127.0.0.1:7897"}
    
    export http_proxy="http://$addr"
    export https_proxy="http://$addr"
    export all_proxy="socks5://$addr"
    export HTTP_PROXY="$http_proxy"
    export HTTPS_PROXY="$https_proxy"
    export ALL_PROXY="$all_proxy"
    
    echo "✅ Proxy ON: $addr"
}
fregister "proxy_on" "设置代理(默认127.0.0.1:7897)"

## 清除代理
proxy_off() {
    unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
    echo "❌ Proxy OFF"
}
alias unproxy='proxy_off'
fregister "proxy_off/unproxy" "清除代理"

## 封装nohup
nohu() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: mynohup <command> [args...]"
        return 1
    fi

    local temp_dir="${TMPDIR:-/tmp}"
    temp_dir="${temp_dir%/}/"
    
    local cmd_name=$(basename "$1")
    local current_timestamp=$(date +%Y%m%d_%H%M%S)
    local nohup_log="${temp_dir}nohup_${cmd_name}_${current_timestamp}.log"
    
    nohup "$@" > "$nohup_log" 2>&1 &
    
    local pid=$!
    
    echo "------------------------------------------"
    echo "Process started in background."
    echo "Command:  $*"
    echo "PID:      $pid"
    echo "Log file: $nohup_log"
    echo "------------------------------------------"
    
    sleep 0.5
    if ! kill -0 $pid 2>/dev/null; then
        echo "Warning: Process $pid seems to have exited immediately. Check the log."
    fi
}
fregister "nohu" "在后台运行命令并输出日志到临时文件"

## git commit browser with fzf
glf() {
  git log --graph --color=always \
      --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" | \
  fzf --ansi --no-sort --reverse --tiebreak=index \
      --preview "echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs git show --color=always --stat" \
      --header "Enter: 查看完整Diff | CTRL-D: 仅查看文件列表" \
      --bind "enter:execute(echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I % sh -c 'git show --color=always % | less -R')" \
      --bind "ctrl-d:change-preview(echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs git show --color=always --name-only)" \
      --preview-window=right:60%
}
fregister "glf" "git log browser with fzf"

gh-token() {
  if ! command -v gh &>/dev/null; then
    echo "错误: 未找到 gh 命令，请先安装 GitHub CLI。"
    return 1
  fi

  local token
  token=$(gh auth token 2>/dev/null)

  if [ -n "$token" ]; then
    export GITHUB_TOKEN="$token"
    export MISE_GITHUB_TOKEN="$token"
    echo "✅ 已成功设置 GITHUB_TOKEN 和 MISE_GITHUB_TOKEN"
  else
    echo "❌ 错误: 无法获取 Token。请确保已运行 'gh auth login' 登录。"
    return 1
  fi
}
fregister "gh-token" "设置 GitHub Token 环境变量"

# -----------------------------------------------------------------------------
# Python Helpers
# -----------------------------------------------------------------------------

# Get local IP address via Python
alias pyip="python3 -c \"import socket;print([(s.connect(('8.8.8.8', 53)), s.getsockname()[0], s.close()) for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]][0][1])\""
fregister "pyip" "获取本地IP地址"

# Get current time via Python
alias pytime="python3 -c \"import datetime; print(datetime.datetime.now().strftime('%Y/%m/%d %H:%M:%S'))\""
fregister "pytime" "获取当前时间"

## 快速开启python http服务
pyhttp(){
    # 如果没有传入端口号，使用默认端口7788
    local port=${1:-7788}

    echo "启动 Python HTTP 服务器，监听端口 $port..."
    python3 -m http.server "$port"
}
fregister "pyhttp" "快速开启python http服务"
