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
export PATH="$HOME/.local/bin:$HOME/go/bin:/usr/local/sbin:$PATH"

# Editor
export EDITOR=/usr/local/bin/nvim
export VISUAL=/usr/local/bin/nvim

# fzf
export FZF_DEFAULT_COMMAND='fd --type f'
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
export ZPLUG_HOME=/usr/local/opt/zplug
source $ZPLUG_HOME/init.zsh

zplug "zsh-users/zsh-syntax-highlighting", defer:2
zplug "zsh-users/zsh-history-substring-search"
zplug "zsh-users/zsh-autosuggestions"
zplug "zsh-users/zsh-history-substring-search"

zplug "plugins/git",   from:oh-my-zsh

zplug denysdovhan/spaceship-prompt, use:spaceship.zsh, from:github, as:theme

# Spaceship config
SPACESHIP_TIME_SHOW=true
SPACESHIP_PACKAGE_SHOW=false

if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

zplug load