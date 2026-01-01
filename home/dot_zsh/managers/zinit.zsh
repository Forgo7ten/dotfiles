# ==================================================
# Zinit plugin manager
# ==================================================

## p10k need
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

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


## zinit附件
zinit light-mode for \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zdharma-continuum/zinit-annex-patch-dl \
  zdharma-continuum/zinit-annex-readurl \
  zdharma-continuum/zinit-annex-binary-symlink \
  zdharma-continuum/zinit-annex-submods
  # zdharma-continuum/zinit-annex-link-man 会顶替掉$MANPATH导致系统的找不到

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

zinit lucid light-mode for \
    OMZL::directories.zsh \
    OMZL::functions.zsh \
    \
    OMZL::clipboard.zsh \
    OMZL::cli.zsh \
    OMZL::correction.zsh \
    OMZL::grep.zsh \
    OMZL::history.zsh \
    OMZL::key-bindings.zsh \
    OMZL::misc.zsh \
    OMZL::termsupport.zsh


##  omz主题会需要的东西，使用p10k可忽略
# zinit snippet OMZL::async_prompt.zsh
# zinit snippet OMZL::git.zsh
# zinit snippet OMZL::prompt_info_functions.zsh
# zinit snippet OMZL::theme-and-appearance.zsh
# zinit snippet OMZL::vcs_info.zsh
## 忽略掉的一些：
# OMZL::compfix.zsh 用于检查目录权限，现代系统不需要
# OMZL::completion.zsh 使用了 fzf-tab 和 zsh-completions，不再需要
# OMZL::diagnostics.zsh 仅用于调试 OMZ
# OMZL::spectrum.zsh 仅用于定义终端颜色变量


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
  MichaelAquilina/zsh-you-should-use # 有别名时提示使用
)

# 一次性交给 Zinit 加载
zinit wait lucid light-mode for "${ld_plugins[@]}"


# --------------------------------------------------
# 3. 初始化 Prompt / Theme
# --------------------------------------------------
# Prompt should NOT block shell startup.
# Use wait'!' to load after first prompt render.

## 安装gitstatus 加快git索引（p10k已集成）
# zinit ice pick"gitstatus.prompt.zsh"
# zinit load romkatv/gitstatus

zinit ice depth=1; zinit light romkatv/powerlevel10k
[[ ! -f $HOME/.zsh/.p10k.zsh ]] || source $HOME/.zsh/.p10k.zsh

# --------------------------------------------------
# 4. 其他工具
# --------------------------------------------------

## jq 处理json输出
zinit light-mode wait"1" lucid from"gh-r" as"null" \
  atclone"./jq --version" atpull"%atclone" \
  sbin"jq* -> jq" \
  for jqlang/jq

## load zoxide: 'z' 目录快速跳转
zinit light-mode wait"1" lucid from"gh-r" \
  atclone"./zoxide init zsh > init.zsh" atpull"%atclone" \
  sbin"zoxide" src"init.zsh" \
  for ajeetdsouza/zoxide

# load direnv
zinit light-mode from"gh-r" mv"direnv* -> direnv" \
  atclone"./direnv hook zsh > zhook.zsh" atpull"%atclone" \
  sbin"direnv" src"zhook.zsh" \
  for direnv/direnv

## zsh vim模式
#zinit ice depth=1
#zinit light jeffreytse/zsh-vi-mode

## bat渲染
zinit ice wait"1" lucid from"gh-r" as"null" \
  atclone"cp -vf bat-*/autocomplete/bat.zsh _bat" atpull"%atclone" \
  sbin"bat-*/bat -> bat" man"bat-*/bat.1"
zinit light sharkdp/bat

## fzf
# Ctrl+R 快速寻找hisotry
# Ctrl+R 快速寻找当前目录下文件
# Alt+C  快速寻找当前目录下的目录
zinit ice wait"1" lucid from"gh-r" \
    atclone"./fzf --zsh > fzf-init.zsh" atpull"%atclone" \
    sbin"fzf" src"fzf-init.zsh"
zinit light junegunn/fzf

# SDKMAN 配置
zinit ice wait"1" lucid id-as"local/sdkman" atload'
  export SDKMAN_DIR="$HOME/.sdkman"
  [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
'
zinit light zdharma-continuum/null

# NVM 配置
zinit ice wait"1" lucid id-as"local/nvm" atload'
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
'
zinit light zdharma-continuum/null

# thefuck 配置(不存在时忽略报错、不会自动安装)
zinit wait'1' lucid light-mode for \
  id-as"local/thefuck" \
  atload'(( $+commands[thefuck] )) && eval $(thefuck --alias)' \
  zdharma-continuum/null
