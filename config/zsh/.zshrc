# Startup progress
source ~/.config/zsh/startup.zsh
__zsh_startup_begin "Shell options"

# Tab completion
zstyle ':completion:*' matcher-list 'm:{[:lower:]}={[:upper:]}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ''
unsetopt LIST_BEEP
setopt MENU_COMPLETE

# Key bindings
bindkey '[C' forward-word
bindkey '[D' backward-word

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
__zsh_startup_end

# Path
__zsh_startup_begin "Homebrew + PATH"
if [[ -x /opt/homebrew/bin/brew ]]; then
	eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
	eval "$(/usr/local/bin/brew shellenv)"
fi
export PATH="$HOME/.local/bin:/usr/local/sbin:$PATH"
export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"
if [ -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" ]; then
	export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"
fi

# Editor
export EDITOR="code --wait"
export VISUAL="code --wait"
__zsh_startup_end

# fzf
__zsh_startup_begin "fzf"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
bindkey "^[[A" history-beginning-search-backward
bindkey "^[[B" history-beginning-search-forward
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
__zsh_startup_end

# Aliases and functions
__zsh_startup_begin "Aliases + functions"
source ~/.config/zsh/aliases.zsh
source ~/.config/zsh/functions.zsh
__zsh_startup_end

# fnm
__zsh_startup_begin "fnm"
if command -v fnm >/dev/null 2>&1; then
	eval "$(fnm env --shell zsh --version-file-strategy=recursive --resolve-engines=false)"
	autoload -U add-zsh-hook
	add-zsh-hook -D chpwd _fnm_auto_use
	add-zsh-hook chpwd _fnm_auto_use
	_fnm_auto_use
else
	echo "fnm unavailable. Run: dotfiles brew" >&2
fi
__zsh_startup_end

# Local zsh config
__zsh_startup_begin "Local config"
if [ -f "$HOME/.zshrc.local" ]; then
	source "$HOME/.zshrc.local"
fi
__zsh_startup_end

# Plugins
__zsh_startup_begin "Zsh plugins"
source "${HOME}/.zgen/zgen.zsh"

if ! zgen saved; then
	echo "Creating a zgen save"

	zgen load zsh-users/zsh-syntax-highlighting
	zgen load zsh-users/zsh-history-substring-search
	zgen load zsh-users/zsh-autosuggestions
	zgen load

	zgen save
fi
__zsh_startup_end

# Initialise Starship
__zsh_startup_begin "Starship"
eval "$(starship init zsh)"
__zsh_startup_end

# OnePassword Completions
__zsh_startup_begin "1Password completion"
eval "$(op completion zsh)"
compdef _op op
__zsh_startup_end

__zsh_startup_finish
