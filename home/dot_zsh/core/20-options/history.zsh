# ==================================================
# Zsh History
# ==================================================

# 设置历史文件存放位置
HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"

# 设置历史时间格式
HIST_STAMPS="yyyy-mm-dd"

# 设置内存历史条数
HISTSIZE=50000
# 设置保存磁盘历史条数
SAVEHIST=50000

# 删除旧的重复历史记录，只保留最近一次
# setopt HIST_IGNORE_ALL_DUPS

# 不保存以空格开头的命令
# 可用于临时避免敏感命令进入 history
setopt HIST_IGNORE_SPACE

# 保存命令执行时间
setopt EXTENDED_HISTORY

# 多个 Zsh 会话实时共享历史记录
setopt SHARE_HISTORY

# 搜索历史时跳过重复结果
setopt HIST_FIND_NO_DUPS

# 执行历史扩展后，不立即执行，而是先放到命令行中确认
# setopt HIST_VERIFY
