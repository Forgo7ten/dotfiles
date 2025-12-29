# ==================================================
# Zinit plugin manager
# ==================================================

# --------------------------------------------------
# 1. Bootstrap zinit
# --------------------------------------------------
# Responsibility:
# - Ensure zinit is installed
# - Source zinit entrypoint
# - Do NOT load any plugins or shell logic here

ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -r "$ZINIT_HOME/zinit.zsh" ]]; then
  print -P "%F{33}Installing Zinit (%F{220}zdharma-continuum/zinit%F{33})…%f"
  command mkdir -p "$(dirname "$ZINIT_HOME")" \
    && command git clone https://github.com/zdharma-continuum/zinit "$ZINIT_HOME" \
    && print -P "%F{34}Zinit installation successful.%f" \
    || print -P "%F{160}Zinit installation failed.%f"
fi

source "$ZINIT_HOME/zinit.zsh"

autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit


# --------------------------------------------------
# 2. 初始化 Oh My Zsh
# --------------------------------------------------
# OMZ is used as a runtime framework:
# - zinit is the loader
# - OMZ provides shell semantics (libs + plugins)
# - No OMZ::init.zsh (black-box init) is used


# --------------------------------------------------
# 2.1 初始化 OMZ lib
# --------------------------------------------------

# --------------------------------------------------
# 2.1.1 Core / Required libs (SYNC)
# --------------------------------------------------
# These libs define OMZ runtime semantics.
# They MUST be loaded synchronously and BEFORE plugins.

zinit snippet OMZL::async_prompt.zsh
zinit snippet OMZL::directories.zsh
zinit snippet OMZL::functions.zsh
zinit snippet OMZL::git.zsh
zinit snippet OMZL::prompt_info_functions.zsh
zinit snippet OMZL::theme-and-appearance.zsh
zinit snippet OMZL::vcs_info.zsh


# --------------------------------------------------
# 2.1.2 Extra / UX libs (ASYNC, Turbo mode)
# --------------------------------------------------
# These libs enhance UX but are NOT required for shell startup.
# They are safe to load asynchronously after prompt is shown.

zinit wait lucid for \
  OMZL::clipboard.zsh \
  OMZL::cli.zsh \
  OMZL::compfix.zsh \
  OMZL::completion.zsh \
  OMZL::correction.zsh \
  OMZL::diagnostics.zsh \
  OMZL::grep.zsh \
  OMZL::history.zsh \
  OMZL::key-bindings.zsh \
  OMZL::misc.zsh \
  OMZL::spectrum.zsh \
  OMZL::termsupport.zsh

# --------------------------------------------------
# 2.2 初始化 plugins
# --------------------------------------------------
# Plugins assume OMZ libs are already loaded.
# They are safe to load asynchronously.

# 定义插件列表数组
local -a ld_plugins=(
    OMZP::git                # Git 基础增强
    OMZP::copypath           # copypath: 复制当前路径
    OMZP::copyfile           # copyfile: 复制文件内容到系统剪贴板
    OMZP::copybuffer         # ctrl-o 快捷键拷贝当前命令行缓冲区的命令
    OMZP::sudo               # 按两次 Esc 加 sudo
    OMZP::extract            # x: 解压压缩包
    OMZP::gitignore          # gi: 查询 gitignore 模板。
    OMZP::cp                 # cpv: 做rsync 的别名
    OMZP::command-not-found  # 缺失命令提示
    # OMZP::z                  # z: 目录快速跳转
    # OMZP::autojump           # 目录跳转增强
    atinit'command -v zoxide >/dev/null && eval "$(zoxide init zsh)"' id-as"zoxide-init" zdharma-continuum/null # z: 目录快速跳转
)


# 一次性交给 Zinit 加载
zinit wait lucid light-mode for "${ld_plugins[@]}"

# --------------------------------------------------
# 3. 初始化 Prompt / Theme
# --------------------------------------------------
# Prompt should NOT block shell startup.
# Use wait'!' to load after first prompt render.

zinit ice depth=1; zinit light romkatv/powerlevel10k
[[ ! -f $HOME/.zsh/.p10k.zsh ]] || source $HOME/.zsh/.p10k.zsh

# --------------------------------------------------
# 4. 其他工具
# --------------------------------------------------


# load direnv
zinit light-mode for \
    id-as"local/direnv" atinit'command -v direnv >/dev/null || return 1' atload'eval "$(direnv hook zsh)"' \
    zdharma-continuum/null

# SDKMAN 配置
zinit ice wait"0" lucid id-as"sdkman" atload'
  export SDKMAN_DIR="$HOME/.sdkman"
  [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
'
zinit light zdharma-continuum/null

# NVM 配置
zinit ice wait"0" lucid id-as"nvm" atload'
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
'
zinit light zdharma-continuum/null