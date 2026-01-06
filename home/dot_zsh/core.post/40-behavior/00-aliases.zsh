# Core: Aliases
# General aliases and OS-specific shortcuts

# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------

if command -v eza > /dev/null; then
  unalias lf lg 2>/dev/null
  ## eza alias
  _EZA_BASIC='eza -lah --icons --git --group-directories-first --color-scale'

  alias ls='eza -a --icons --group-directories-first --hyperlink'
  alias l="$_EZA_BASIC"
  alias ll="l --hyperlink"
  function lg() {
    local eza_cmd="$_EZA_BASIC --color=always"
    
    if [ $# -eq 1 ]; then
      eval "$eza_cmd" | grep --color=always -i "$1"
    elif [ $# -ge 2 ]; then
      local target_path="$1"
      shift
      eval "$eza_cmd $target_path" | grep --color=always -i "$@"
    else
      eval "$eza_cmd"
    fi
  }
  function lf() {
    ll -d *"$1"*(ND)
  }
  function lf() {
    local eza_cmd="$_EZA_BASIC"

    if [ $# -eq 1 ]; then
      eval "$eza_cmd" -d *"$1"*(ND)
    elif [ $# -ge 2 ]; then
      eval "$eza_cmd" -d "$1"/*"$2"*(ND)
    else
      # 无参数：列出当前所有
      eval "$eza_cmd"
    fi
  }
  alias lr='eza -lah --icons --sort=modified --color-scale'
  alias lt='eza -T --icons --group-directories-first'
  alias lt2='lt -L 2'
  alias lt3='lt -L 3'
  alias lt4='lt -L 4'
else
  alias ll="ls -alF"
  alias lg="ll | grep"
fi

## nvim代替vim
alias nvi="nvim"
alias vi="nvim"

## zellij创建session
alias za="zellij a -c"
