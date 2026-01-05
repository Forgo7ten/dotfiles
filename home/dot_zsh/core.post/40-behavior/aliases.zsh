# Core: Aliases
# General aliases and OS-specific shortcuts

# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------

# alias ll="ls -alF"
# alias lg="ll | grep"

## eza alias
_EZA_BASIC='eza -lah --icons --git --group-directories-first --color-scale'

alias ls='eza -a --icons --group-directories-first --hyperlink'
alias ll="$_EZA_BASIC --hyperlink"
alias l='ll'
alias lg="$_EZA_BASIC --color=always | grep --color=always"
lf() {
  ll -d *"$1"*(ND)
}
alias lr='eza -lah --icons --sort=modified --color-scale'
alias lt='eza -T --icons --group-directories-first'
alias lt2='lt -L 2'
alias lt3='lt -L 3'
alias lt4='lt -L 4'

## nvim代替vim
alias nvi="nvim"
alias vi="nvim"

## zellij创建session
alias za="zellij a -c"
