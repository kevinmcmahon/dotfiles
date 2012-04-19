# Recursively delete `.DS_Store` files
alias cleanup="find . -name '*.DS_Store' -type f -ls -delete"

# Shortcuts
alias d="cd ~/Dropbox"
alias dl="cd ~/Downloads"
alias p="cd ~/Projects"
alias a="cd ~/Projects/android"
alias g="git"
alias v="vim"
alias m="mate ."
alias work="cd ~/work"

# Hide/show all desktop icons (useful when presenting)
alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"

alias ll='ls -lHG'
alias la='ls -laHG'
alias ..='cd ..'
alias ...='cd ../..'

# git aliases
alias ga='git add'
alias gs='git status'
alias g='git'
alias gc='git commit'
alias gp='git pull'

alias reload="source $HOME/.bashrc"


