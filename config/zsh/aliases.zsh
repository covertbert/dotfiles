alias vim='nvim'
alias ~='cd ~'
alias pys='python -m SimpleHTTPServer'
alias code='open -a Visual\ Studio\ Code.app'

alias l='ls -lFh'     #size,show type,human readable
alias la='ls -lAFh'   #long list,show almost all,show type,human readable
alias ll='ls -l'      #long list

alias grep='grep --color'
alias sgrep='grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS} '

alias t='tail -f'

# Make zsh know about hosts already accessed by SSH
zstyle -e ':completion:*:(ssh|scp|sftp|rsh|rsync):hosts' hosts 'reply=(${=${${(f)"$(cat {/etc/ssh_,~/.ssh/known_}hosts(|2)(N) /dev/null)"}%%[# ]*}//,/ })'


alias g='git'
alias gaa='git add --all'
alias gcmsg='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gcl='git clone --recurse-submodules'
alias gss='git status -s'

