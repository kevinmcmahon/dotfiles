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
alias o="open ."
alias work="cd ~/work"
alias apps="cd ~/Projects/apps"

alias bex='bundle exec'
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
alias gsu='git submodule update'
alias gl="git log --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"

alias reload="source $HOME/.bashrc"

alias ded="rm -rf /Users/kevin/Library/Developer/Xcode/DerivedData"

alias fixbootstrap="launchctl list|grep UIKitApplication|awk '{print $3}'|xargs launchctl remove"

alias fixopenwith='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user'
