# Recursively delete `.DS_Store` files
alias cleanup="find . -name '*.DS_Store' -type f -ls -delete"

# Shortcuts
alias d="cd ~/Dropbox"
alias p="cd ~/Projects"
alias g="git"
alias v="vim"
alias m="mate ."

# Hide/show all desktop icons (useful when presenting)
alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"

alias la='ls -la'
alias ..='cd ..'

# git aliases
alias ga='git add'
alias gs='git status'
alias g='git'
