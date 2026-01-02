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

## 清除代理
proxy_off() {
    unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
    echo "❌ Proxy OFF"
}
alias unproxy='proxy_off'

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

