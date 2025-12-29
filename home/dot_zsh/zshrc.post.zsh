# ~/.zsh/zshrc_post
# Post-configuration that runs after all plugins are loaded
# This file is sourced at the very end of Zsh initialization

# --------------------------------------------------
# Manager-specific post-load configurations
# --------------------------------------------------

_zinit_post(){
    zinit wait lucid for \
    atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
        zdharma-continuum/fast-syntax-highlighting \
    blockf \
        zsh-users/zsh-completions \
    atload"!_zsh_autosuggest_start" \
        zsh-users/zsh-autosuggestions
}
_zimfw_post(){

}

case "$ZSH_MANAGER" in
  zinit)
    _zinit_post
    ;;
    
  zimfw)
    _zimfw_post
    ;;
    
  none)
    autoload -Uz compinit
    compinit

    ;;
esac
