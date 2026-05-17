alias vim='nvim'
alias vi='nvim'
alias zshconfig='vi ~/.zshrc'

alias cleanup="find . -name '*.DS_Store' -type f -ls -delete"
alias rmorig='find . -name "*.orig" -print0 | xargs -0 rm -rf'

alias cls='clear'
alias p='cd ~/work'
alias f='fzf'
alias y='yazi'

alias cat='bat'
alias bcat='/bin/cat'
alias ls='eza --long --color=always --icons=always --no-user --no-time --group-directories-first'

unalias la ll 2>/dev/null

alias ll='eza --long --color=always --icons=always --header --git --group-directories-first'
alias la='ll --no-time --group-directories-first --all'

alias g='git'
alias gp='git pull --rebase'
alias gs='git st'
alias ga='git add'
alias stash='git stash'
alias pop='git stash pop'
alias gdiff='git diff'

alias t='tmux attach -t main 2>/dev/null || tmux new -s main'
alias tdev='tmux attach -t dev 2>/dev/null || tmux new -s dev'

alias -s json='jq .'
alias -s {yaml,yml}='bat -l yaml'
alias -s md=bat
alias -s py='uv run'

alias -g G='| rg'
alias -g L='| less'
alias -g J='| jq .'
alias -g W='| wc -l'
alias -g H='| head'
alias -g T='| tail'
alias -g NUL='> /dev/null 2>&1'
alias -g ERR='2>&1'

alias cld='claude'
alias cldy='claude --dangerously-skip-permissions'

alias md='mkdir -p'
