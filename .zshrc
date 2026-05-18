export ZSH=$HOME/.oh-my-zsh
ZSH_THEME="osx"
plugins=(
  git 
  zsh-autosuggestions 
  zsh-syntax-highlighting 
  bgnotify
  zsh-fzf-history-search
  zsh-autocomplete
)

PATH="$PREFIX/bin:$HOME/.local/bin:$PATH"
export PATH

LINK="https://github.com/FebriCahyaa"
export LINK

LINK_SSH="git@github.com:FebriCahyaa"
export LINK_SSH

export TERM=xterm-256color 

source $ZSH/oh-my-zsh.sh
source $HOME/.config/lf/icons

# Prediction List View
zstyle ':autocomplete:*' min-delay 1.0
zstyle ':autocomplete:*' list-lines 4
zstyle ':completion:*:warnings' format ''
#zstyle ':autocomplete:*' default-context history-incremental-search-backward

source $HOME/.aliases
source $HOME/.autostart
