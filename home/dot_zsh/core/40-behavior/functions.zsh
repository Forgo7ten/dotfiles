# 设置代理
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

# 清除代理
proxy_off() {
    unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
    echo "❌ Proxy OFF"
}
alias unproxy='proxy_off'
