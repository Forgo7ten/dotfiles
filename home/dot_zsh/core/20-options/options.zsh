# 设置历史时间格式
HIST_STAMPS="yyyy-mm-dd"

# 命令位的变量补全，屏蔽大写开头的变量（通常是系统环境变量）
zstyle ':completion:*:*:-command-*:parameters' ignored-patterns '[A-Z]*'

# 让通配符可以匹配隐藏文件
setopt GLOB_DOTS