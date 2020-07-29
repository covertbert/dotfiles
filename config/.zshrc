# Tab completion
zstyle ':completion:*' matcher-list 'm:{[:lower:]}={[:upper:]}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ''
unsetopt LIST_BEEP
setopt MENU_COMPLETE

# History
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=10000

setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY

# Changing Directories
setopt AUTO_CD
setopt CHASE_LINKS

# Path
export PATH="$HOME/.local/bin:/usr/local/sbin:$PATH"

# Editor
export EDITOR=/usr/local/bin/nvim
export VISUAL=/usr/local/bin/nvim

# fzf
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
bindkey "^[[A" history-beginning-search-backward
bindkey "^[[B" history-beginning-search-forward
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Aliases
source ~/.config/zsh/aliases.zsh

# Functions
source ~/.config/zsh/functions.zsh

# iTerm 2
source ~/.config/zsh/iterm2.zsh

# Local zsh config
if [ -f "$HOME/.zshrc.local" ]; then
    source "$HOME/.zshrc.local"
fi

# Plugins
source "${HOME}/.zgen/zgen.zsh"

if ! zgen saved; then
    echo "Creating a zgen save"

    zgen load zsh-users/zsh-syntax-highlighting
    zgen load zsh-users/zsh-history-substring-search
    zgen load zsh-users/zsh-autosuggestions
    zgen load

    zgen save
fi

eval "$(starship init zsh)"
