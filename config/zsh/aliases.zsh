alias vim='nvim'
alias ~='cd ~'
alias pys='python -m SimpleHTTPServer'
alias code='open -a Visual\ Studio\ Code.app'

alias z='source ~/.zshrc'

alias ls='logo-ls'
alias l='logo-ls -la'
alias lr='logo-ls -R'
alias lg='logo-ls -D'

alias grep='grep --color'
alias sgrep='grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS} '

alias sed='gsed'
alias grep='ggrep'

alias t='tail -f'

alias top='bpytop'

# Make zsh know about hosts already accessed by SSH
zstyle -e ':completion:*:(ssh|scp|sftp|rsh|rsync):hosts' hosts 'reply=(${=${${(f)"$(cat {/etc/ssh_,~/.ssh/known_}hosts(|2)(N) /dev/null)"}%%[# ]*}//,/ })'

alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gb='git branch'
alias gbd='git branch -d'
alias gcl='git clone --recurse-submodules'
alias gcmsg='git commit -m'
alias gcmsgn='git commit --no-verify -m'
alias gd='git diff'
alias gp='git push'
alias gl='git pull'
alias gss='git status -s'
alias gco='git checkout'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias gpristine='git reset --hard && git clean -df'
